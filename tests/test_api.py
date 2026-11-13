"""Pruebas de los reintentos y errores de red de api_post.

No necesitan red ni clave real: simulan la respuesta de urllib.

    python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

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


if __name__ == "__main__":
    unittest.main()
