"""Pruebas de los comandos de grabación y purga.

No necesitan micrófono, red ni escritorio: simulan los procesos externos.

    python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import io
import importlib.util
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
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


class FakeProcess:
    pid = 1234

    def poll(self) -> None:
        return None


class StartNotificationTest(unittest.TestCase):
    def test_message_does_not_depend_on_the_hotkey(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            with mock.patch.object(dictado, "recording_state", return_value=None), \
                    mock.patch.object(dictado, "which", return_value="/usr/bin/arecord"), \
                    mock.patch.object(dictado, "STATE_DIR", tmp_path), \
                    mock.patch.object(dictado, "LOG_FILE", tmp_path / "arecord.log"), \
                    mock.patch.object(dictado.subprocess, "Popen", return_value=FakeProcess()), \
                    mock.patch.object(dictado.time, "sleep"), \
                    mock.patch.object(dictado, "active_window", return_value="1"), \
                    mock.patch.object(dictado, "window_class", return_value=""), \
                    mock.patch.object(dictado, "write_state"), \
                    mock.patch.object(dictado, "notify") as notify:
                self.assertEqual(dictado.cmd_start(dictado.DEFAULTS), 0)

        notify.assert_called_once()
        self.assertEqual(notify.call_args.args[1], "Pulsa tu atajo de nuevo para parar.")


class StopPendingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.wav = self.dir / "rec-20260101-120000.wav"
        self.wav.write_bytes(b"audio" * 1024)
        self.trim = Path(str(self.wav) + ".trim.wav")
        self.trim.write_bytes(b"trim")
        self.pending = self.dir / "pending"
        self.state = {"pid": 1234, "wav": str(self.wav)}

    def run_stop(self):
        with mock.patch.object(dictado, "recording_state", return_value=self.state), \
                mock.patch.object(dictado, "pid_alive", return_value=False), \
                mock.patch.object(dictado.os, "kill"), \
                mock.patch.object(dictado, "clear_state"), \
                mock.patch.object(dictado, "PENDING_DIR", self.pending), \
                mock.patch.object(
                    dictado, "process_recording",
                    side_effect=dictado.DictadoError("falló la transcripción"),
                ), \
                mock.patch.object(dictado, "notify"), \
                mock.patch.object(dictado, "append_history"), \
                redirect_stderr(io.StringIO()):
            return dictado.cmd_stop(dictado.DEFAULTS)

    def test_removes_original_audio_after_copying_it(self) -> None:
        self.assertEqual(self.run_stop(), 1)

        self.assertTrue((self.pending / self.wav.name).exists())
        self.assertFalse(self.wav.exists())
        self.assertFalse(self.trim.exists())

    def test_keeps_original_audio_if_the_copy_fails(self) -> None:
        self.pending.write_text("no es un directorio", encoding="utf-8")

        self.assertEqual(self.run_stop(), 1)

        self.assertTrue(self.wav.exists())
        self.assertTrue(self.trim.exists())


class PurgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.state_dir = self.dir / "state"
        self.pending = self.dir / "pending"
        self.history = self.dir / "history.jsonl"
        self.state_dir.mkdir()
        (self.state_dir / "state.json").write_text("{}", encoding="utf-8")
        (self.state_dir / "arecord.log").write_text("log", encoding="utf-8")
        self.pending.mkdir()
        (self.pending / "old.wav").write_bytes(b"audio")
        self.history.write_text("{}\n", encoding="utf-8")

    def run_purge(self, active: dict | None):
        output = io.StringIO()
        with mock.patch.object(dictado, "STATE_DIR", self.state_dir), \
                mock.patch.object(dictado, "PENDING_DIR", self.pending), \
                mock.patch.object(dictado, "HISTORY_FILE", self.history), \
                mock.patch.object(dictado, "recording_state", return_value=active), \
                redirect_stdout(output):
            code = dictado.cmd_purge(False, True)
        return code, output.getvalue()

    def test_keeps_state_dir_during_an_active_recording(self) -> None:
        code, output = self.run_purge({"pid": 1234, "wav": "rec.wav"})

        self.assertEqual(code, 0)
        self.assertIn("grabación en curso", output)
        self.assertTrue((self.state_dir / "state.json").exists())
        self.assertTrue((self.state_dir / "arecord.log").exists())
        self.assertFalse((self.pending / "old.wav").exists())
        self.assertFalse(self.history.exists())

    def test_clears_state_dir_without_an_active_recording(self) -> None:
        code, output = self.run_purge(None)

        self.assertEqual(code, 0)
        self.assertNotIn("grabación en curso", output)
        self.assertFalse((self.state_dir / "state.json").exists())
        self.assertFalse((self.state_dir / "arecord.log").exists())
        self.assertFalse((self.pending / "old.wav").exists())
        self.assertFalse(self.history.exists())


if __name__ == "__main__":
    unittest.main()
