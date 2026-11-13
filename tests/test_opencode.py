"""Pruebas de la integración opcional con opencode."""

from __future__ import annotations

import io
import json
import os
import stat
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import opencode  # noqa: E402


class OpenCodeIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.config = self.dir / "opencode" / "cli.json"
        self.backup = self.dir / "dictado" / "opencode-backup.json"

    def write_config(self, data: object, mode: int = 0o600) -> None:
        self.config.parent.mkdir(parents=True, exist_ok=True)
        self.config.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        os.chmod(self.config, mode)

    def read_config(self) -> object:
        return json.loads(self.config.read_text(encoding="utf-8"))

    def run_apply(self, dry_run: bool = False) -> tuple[int, str]:
        output = io.StringIO()
        with redirect_stdout(output):
            code = opencode.apply(self.config, self.backup, dry_run)
        return code, output.getvalue()

    def run_revert(self, dry_run: bool = False) -> tuple[int, str]:
        output = io.StringIO()
        with redirect_stdout(output):
            code = opencode.revert(self.backup, dry_run)
        return code, output.getvalue()

    def test_apply_does_not_create_a_missing_config(self) -> None:
        code, _ = self.run_apply()
        self.assertEqual(code, opencode.EXIT_NOT_APPLICABLE)
        self.assertFalse(self.config.exists())
        self.assertFalse(self.backup.exists())

    def test_apply_and_revert_without_previous_key(self) -> None:
        self.write_config({"theme": "dark"})
        code, _ = self.run_apply()
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertEqual(self.read_config(), {"theme": "dark", "prompt": {"paste": "full"}})
        self.assertTrue(self.backup.exists())
        self.assertEqual(stat.S_IMODE(self.backup.stat().st_mode), 0o600)

        code, _ = self.run_revert()
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertEqual(self.read_config(), {"theme": "dark"})
        self.assertFalse(self.backup.exists())

    def test_apply_and_revert_with_previous_value(self) -> None:
        original = {
            "theme": "dark",
            "prompt": {"paste": "compact", "other": 1},
        }
        self.write_config(original)
        code, _ = self.run_apply()
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertEqual(
            self.read_config(),
            {
                "theme": "dark",
                "prompt": {"paste": "full", "other": 1},
            },
        )

        code, _ = self.run_revert()
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertEqual(self.read_config(), original)

    def test_reinstall_keeps_the_original_backup(self) -> None:
        self.write_config({"prompt": {"paste": "compact"}})
        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        backup_before = self.backup.read_text(encoding="utf-8")

        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        self.assertEqual(self.backup.read_text(encoding="utf-8"), backup_before)

        self.assertEqual(self.run_revert()[0], opencode.EXIT_OK)
        self.assertEqual(self.read_config(), {"prompt": {"paste": "compact"}})

    def test_revert_respects_a_later_user_change(self) -> None:
        self.write_config({"prompt": {"paste": "compact"}})
        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        self.write_config({"prompt": {"paste": "collapsed"}})

        code, output = self.run_revert()
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertIn("cambió después", output)
        self.assertEqual(self.read_config(), {"prompt": {"paste": "collapsed"}})
        self.assertFalse(self.backup.exists())

    def test_apply_rejects_invalid_json(self) -> None:
        self.config.parent.mkdir(parents=True, exist_ok=True)
        self.config.write_text("{ roto\n", encoding="utf-8")
        code, output = self.run_apply()
        self.assertEqual(code, opencode.EXIT_UNSAFE)
        self.assertIn("JSON válido", output)
        self.assertEqual(self.config.read_text(encoding="utf-8"), "{ roto\n")
        self.assertFalse(self.backup.exists())

    def test_apply_rejects_a_non_object_prompt(self) -> None:
        self.write_config({"prompt": "texto"})
        code, output = self.run_apply()
        self.assertEqual(code, opencode.EXIT_UNSAFE)
        self.assertIn("no es un objeto", output)
        self.assertEqual(self.read_config(), {"prompt": "texto"})
        self.assertFalse(self.backup.exists())

    def test_revert_without_backup(self) -> None:
        code, output = self.run_revert()
        self.assertEqual(code, opencode.EXIT_NOT_APPLICABLE)
        self.assertIn("no hay copia", output)

    def test_revert_discards_backup_if_config_disappeared(self) -> None:
        self.write_config({"prompt": {"paste": "compact"}})
        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        self.config.unlink()

        code, output = self.run_revert()
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertIn("ya no existe", output)
        self.assertFalse(self.backup.exists())

    def test_dry_run_does_not_change_anything(self) -> None:
        self.write_config({"prompt": {"paste": "compact"}})
        code, output = self.run_apply(dry_run=True)
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertIn("pondría", output)
        self.assertEqual(self.read_config(), {"prompt": {"paste": "compact"}})
        self.assertFalse(self.backup.exists())

        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        backup_before = self.backup.read_text(encoding="utf-8")
        code, output = self.run_revert(dry_run=True)
        self.assertEqual(code, opencode.EXIT_OK)
        self.assertIn("revertiría", output)
        self.assertEqual(self.read_config(), {"prompt": {"paste": "full"}})
        self.assertEqual(self.backup.read_text(encoding="utf-8"), backup_before)

    def test_config_mode_is_preserved(self) -> None:
        self.write_config({"prompt": {"paste": "compact"}}, mode=0o640)
        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)

    def test_symlinked_config_is_preserved(self) -> None:
        real = self.dir / "dotfiles" / "cli.json"
        real.parent.mkdir(parents=True)
        real.write_text('{"prompt": {"paste": "compact"}}\n', encoding="utf-8")
        self.config.parent.mkdir(parents=True)
        self.config.symlink_to(real)

        self.assertEqual(self.run_apply()[0], opencode.EXIT_OK)
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(json.loads(real.read_text(encoding="utf-8"))["prompt"]["paste"], "full")

        self.assertEqual(self.run_revert()[0], opencode.EXIT_OK)
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(json.loads(real.read_text(encoding="utf-8"))["prompt"]["paste"], "compact")


if __name__ == "__main__":
    unittest.main()
