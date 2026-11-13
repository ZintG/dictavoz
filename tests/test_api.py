"""Pruebas de los reintentos y errores de red de api_post.

No necesitan red ni clave real: simulan la respuesta de urllib.

    python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import copy
import importlib.util
import socket
import sys
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "dictado"

loader = SourceFileLoader("dictado", str(SCRIPT))
spec = importlib.util.spec_from_loader("dictado", loader)
dictado = importlib.util.module_from_spec(spec)
sys.modules["dictado"] = dictado
loader.exec_module(dictado)


class ApiPostTest(unittest.TestCase):
    def test_socket_timeout_is_retried_and_reported(self) -> None:
        timeout_error = socket.timeout("agotado")
        with mock.patch.object(dictado, "api_key", return_value="clave-de-prueba"), \
                mock.patch.object(
                    dictado.urllib.request, "urlopen", side_effect=timeout_error
                ) as urlopen, \
                mock.patch.object(dictado.time, "sleep") as sleep:
            with self.assertRaises(dictado.DictadoError) as ctx:
                dictado.api_post({"input": []}, timeout=1, retries=1)

        self.assertEqual(str(ctx.exception), "tiempo de espera agotado")
        self.assertEqual(urlopen.call_count, 2)
        sleep.assert_called_once_with(1)

    def test_non_json_response_is_reported(self) -> None:
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.read.return_value = b"<html>error</html>"
        with mock.patch.object(dictado, "api_key", return_value="clave-de-prueba"), \
                mock.patch.object(dictado.urllib.request, "urlopen", return_value=response):
            with self.assertRaises(dictado.DictadoError) as ctx:
                dictado.api_post({"input": []}, timeout=1, retries=0)

        self.assertIn("respuesta no válida", str(ctx.exception))

    def test_daily_quota_is_not_retried(self) -> None:
        import io
        import urllib.error

        error = urllib.error.HTTPError(
            "https://example.test", 429, "Too Many Requests",
            {"Retry-After": "120"}, io.BytesIO(b'{"error": {"message": "quota"}}'),
        )
        with mock.patch.object(dictado, "api_key", return_value="clave-de-prueba"), \
                mock.patch.object(
                    dictado.urllib.request, "urlopen", side_effect=error
                ) as urlopen, \
                mock.patch.object(dictado.time, "sleep") as sleep:
            with self.assertRaises(dictado.DictadoError) as ctx:
                dictado.api_post({"input": []}, timeout=1, retries=1)

        self.assertIn("cuota", str(ctx.exception))
        self.assertEqual(urlopen.call_count, 1)
        sleep.assert_not_called()

    def test_transcribe_rejects_oversized_inline_audio(self) -> None:
        oversized = b"x" * (dictado.MAX_INLINE_AUDIO_BYTES + 1)
        with mock.patch.object(dictado.Path, "read_bytes", return_value=oversized):
            with self.assertRaises(dictado.DictadoError) as ctx:
                dictado.transcribe(dictado.Path("rec.wav"), dictado.DEFAULTS)

        self.assertIn("demasiado largo", str(ctx.exception))

    def test_transcribe_payload_uses_store_false_and_verbatim(self) -> None:
        cfg = copy.deepcopy(dictado.DEFAULTS)
        cfg["stt"]["mode"] = "verbatim"
        with mock.patch.object(dictado.Path, "read_bytes", return_value=b"wav"), \
                mock.patch.object(
                    dictado, "api_post", return_value={"output_text": "hola"}
                ) as post:
            self.assertEqual(dictado.transcribe(dictado.Path("rec.wav"), cfg), "hola")

        payload = post.call_args.args[0]
        self.assertIs(payload["store"], False)
        self.assertEqual(
            payload["generation_config"]["transcription_config"]["mode"],
            {"type": "verbatim"},
        )

    def test_model_info_uses_the_metadata_endpoint(self) -> None:
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.read.return_value = b'{"name": "models/gemini-3.5-transcribe"}'
        with mock.patch.object(dictado, "api_key", return_value="clave-de-prueba"), \
                mock.patch.object(
                    dictado.urllib.request, "urlopen", return_value=response
                ) as urlopen:
            data = dictado.api_model_info(
                "gemini-3.5-transcribe", 10, api_base="https://example.test/v1beta"
            )

        self.assertEqual(data["name"], "models/gemini-3.5-transcribe")
        request = urlopen.call_args.args[0]
        self.assertEqual(
            request.full_url,
            "https://example.test/v1beta/models/gemini-3.5-transcribe",
        )


if __name__ == "__main__":
    unittest.main()
