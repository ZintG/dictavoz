"""Pruebas de los comandos de grabación y purga.

No necesitan micrófono, red ni escritorio: simulan los procesos externos.

    python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import io
import importlib.util
import os
import sys
import tempfile
import time
import unittest
import wave
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


class AudioDurationTest(unittest.TestCase):
    def test_falls_back_to_wav_header_without_ffprobe(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "test.wav"
            with wave.open(str(path), "wb") as fh:
                fh.setnchannels(1)
                fh.setsampwidth(2)
                fh.setframerate(8000)
                fh.writeframes(b"\0\0" * 8000)
            with mock.patch.object(dictado, "run", side_effect=OSError("sin ffprobe")):
                self.assertAlmostEqual(dictado.audio_duration(path), 1.0)


class ProcessRecordingTest(unittest.TestCase):
    def test_insert_failure_keeps_the_text_in_history(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            wav = Path(tmp) / "rec.wav"
            wav.write_bytes(b"audio")
            with mock.patch.object(dictado, "audio_duration", return_value=2.0), \
                    mock.patch.object(dictado, "trim_silence", return_value=wav), \
                    mock.patch.object(dictado, "transcribe", return_value="Hola mundo"), \
                    mock.patch.object(dictado, "clean_rules", return_value="Hola mundo"), \
                    mock.patch.object(dictado, "should_polish", return_value=False), \
                    mock.patch.object(
                        dictado, "insert_text",
                        side_effect=dictado.InsertError("xdotool falló", True),
                    ), \
                    mock.patch.object(dictado, "append_history") as history, \
                    mock.patch.object(dictado, "prune_pending"):
                result = dictado.process_recording(wav, {}, dictado.DEFAULTS)

        self.assertFalse(result["inserted"])
        self.assertTrue(result["clipboard"])
        self.assertIn("no se pudo pegar", result["warning"])
        entry = history.call_args.args[0]
        self.assertEqual(entry["final"], "Hola mundo")
        self.assertFalse(entry["inserted"])


class ClipboardCheckTest(unittest.TestCase):
    def test_restores_the_previous_clipboard(self) -> None:
        current = {"value": "centinela"}

        def fake_get() -> str:
            return current["value"]

        def fake_set(value: str) -> bool:
            current["value"] = value
            return True

        with mock.patch.object(dictado, "is_wayland", return_value=False), \
                mock.patch.object(dictado, "get_clipboard", side_effect=fake_get), \
                mock.patch.object(dictado, "set_clipboard", side_effect=fake_set) as setter:
            ok, detail = dictado.clipboard_check()

        self.assertTrue(ok)
        self.assertIn("xclip", detail)
        self.assertEqual(current["value"], "centinela")
        self.assertEqual(setter.call_count, 2)

    def test_restore_process_receives_the_configured_delay(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(dictado, "STATE_DIR", Path(tmp)), \
                    mock.patch.object(dictado.subprocess, "Popen") as popen:
                dictado.restore_clipboard_later("texto", 3000)

        self.assertEqual(popen.call_args.args[0][-1], "3000")


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
                    mock.patch.object(dictado, "prune_pending"), \
                    mock.patch.object(dictado, "notify") as notify:
                self.assertEqual(dictado.cmd_start(dictado.DEFAULTS), 0)

        notify.assert_called_once()
        self.assertEqual(notify.call_args.args[1], "Pulsa tu atajo de nuevo para parar.")

    def test_write_state_failure_stops_arecord(self) -> None:
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
                    mock.patch.object(
                        dictado, "write_state",
                        side_effect=OSError("sin espacio"),
                    ), \
                    mock.patch.object(dictado, "prune_pending"), \
                    mock.patch.object(dictado.os, "kill") as kill:
                with self.assertRaises(dictado.DictadoError):
                    dictado.cmd_start(dictado.DEFAULTS)

        kill.assert_called_once_with(FakeProcess.pid, dictado.signal.SIGKILL)
        self.assertEqual(list(tmp_path.glob("rec-*.wav")), [])


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

    def test_prunes_old_pending_audio_on_error(self) -> None:
        self.pending.mkdir()
        old = self.pending / "old.wav"
        old.write_bytes(b"audio")
        ancient = time.time() - 8 * 86400
        os.utime(old, (ancient, ancient))

        self.assertEqual(self.run_stop(), 1)

        self.assertFalse(old.exists())
        self.assertTrue((self.pending / self.wav.name).exists())


class ConfigCommandTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.config_dir = self.dir / "config"
        self.config_dir.mkdir()
        self.config_file = self.config_dir / "config.toml"
        self.config_file.write_text("esto no es TOML [", encoding="utf-8")

    def test_invalid_config_is_reported_by_status(self) -> None:
        errors = io.StringIO()
        with mock.patch.object(dictado, "CONFIG_FILE", self.config_file), \
                mock.patch.object(dictado, "STATE_FILE", self.dir / "missing.json"), \
                mock.patch.object(dictado, "notify"), \
                redirect_stderr(errors):
            self.assertEqual(dictado.main(["status"]), 1)

        self.assertIn("config.toml inválido", errors.getvalue())

    def test_invalid_config_does_not_block_config_edit(self) -> None:
        with mock.patch.object(dictado, "CONFIG_FILE", self.config_file), \
                mock.patch.object(dictado, "CONFIG_DIR", self.config_dir), \
                mock.patch.object(dictado.subprocess, "call", return_value=0) as call:
            self.assertEqual(dictado.main(["config", "edit"]), 0)

        self.assertEqual(call.call_args.args[0][-1], str(self.config_file))

    def test_editor_arguments_are_respected(self) -> None:
        with mock.patch.object(dictado, "CONFIG_FILE", self.config_file), \
                mock.patch.object(dictado, "CONFIG_DIR", self.config_dir), \
                mock.patch.dict(os.environ, {"EDITOR": "code --wait"}), \
                mock.patch.object(dictado.subprocess, "call", return_value=0) as call:
            self.assertEqual(dictado.cmd_config("edit", dictado.DEFAULTS), 0)

        self.assertEqual(
            call.call_args.args[0],
            ["code", "--wait", str(self.config_file)],
        )
        self.assertEqual(self.config_file.stat().st_mode & 0o777, 0o600)


class PurgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.state_dir = self.dir / "state"
        self.pending = self.dir / "pending"
        self.history = self.dir / "history.jsonl"
        self.config_dir = self.dir / "config"
        self.config_dir.mkdir()
        (self.config_dir / "config.toml").write_text("config", encoding="utf-8")
        self.state_dir.mkdir()
        (self.state_dir / "state.json").write_text("{}", encoding="utf-8")
        (self.state_dir / "arecord.log").write_text("log", encoding="utf-8")
        self.pending.mkdir()
        (self.pending / "old.wav").write_bytes(b"audio")
        self.history.write_text("{}\n", encoding="utf-8")

    def run_purge(self, active: dict | None, purge_all: bool = False):
        output = io.StringIO()
        errors = io.StringIO()
        with mock.patch.object(dictado, "STATE_DIR", self.state_dir), \
                mock.patch.object(dictado, "PENDING_DIR", self.pending), \
                mock.patch.object(dictado, "HISTORY_FILE", self.history), \
                mock.patch.object(dictado, "CONFIG_DIR", self.config_dir), \
                mock.patch.object(dictado, "recording_state", return_value=active), \
                redirect_stdout(output), redirect_stderr(errors):
            code = dictado.cmd_purge(purge_all, True)
        return code, output.getvalue() + errors.getvalue()

    def test_refuses_purge_during_an_active_recording(self) -> None:
        code, output = self.run_purge({"pid": 1234, "wav": "rec.wav"})

        self.assertEqual(code, 1)
        self.assertIn("grabación en curso", output)
        self.assertIn("dictado stop", output)
        self.assertTrue((self.state_dir / "state.json").exists())
        self.assertTrue((self.state_dir / "arecord.log").exists())
        self.assertTrue((self.pending / "old.wav").exists())
        self.assertTrue(self.history.exists())

    def test_refuses_purge_all_during_an_active_recording(self) -> None:
        code, output = self.run_purge({"pid": 1234, "wav": "rec.wav"}, purge_all=True)

        self.assertEqual(code, 1)
        self.assertIn("grabación en curso", output)
        self.assertIn("dictado stop", output)
        self.assertTrue((self.config_dir / "config.toml").exists())
        self.assertTrue((self.state_dir / "state.json").exists())
        self.assertTrue((self.state_dir / "arecord.log").exists())
        self.assertTrue((self.pending / "old.wav").exists())
        self.assertTrue(self.history.exists())

    def test_purge_all_removes_history_config_and_audio(self) -> None:
        code, output = self.run_purge(None, purge_all=True)

        self.assertEqual(code, 0)
        self.assertIn("datos de dictado borrados", output)
        self.assertFalse(self.config_dir.exists())
        self.assertFalse(self.history.exists())
        self.assertFalse((self.pending / "old.wav").exists())
        self.assertFalse((self.state_dir / "state.json").exists())
        self.assertFalse((self.state_dir / "arecord.log").exists())

    def test_clears_state_dir_without_an_active_recording(self) -> None:
        code, output = self.run_purge(None)

        self.assertEqual(code, 0)
        self.assertNotIn("grabación en curso", output)
        self.assertFalse((self.state_dir / "state.json").exists())
        self.assertFalse((self.state_dir / "arecord.log").exists())
        self.assertFalse((self.pending / "old.wav").exists())
        self.assertFalse(self.history.exists())
        self.assertTrue((self.config_dir / "config.toml").exists())


if __name__ == "__main__":
    unittest.main()
