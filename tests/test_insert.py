"""Pruebas de la construcción del comando de inserción con xdotool.

No necesitan red, micrófono ni xdotool: solo comprueban los argumentos.

    python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import importlib.util
import sys
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "dictado"

loader = SourceFileLoader("dictado", str(SCRIPT))
spec = importlib.util.spec_from_loader("dictado", loader)
dictado = importlib.util.module_from_spec(spec)
sys.modules["dictado"] = dictado
loader.exec_module(dictado)


class InsertCommandTest(unittest.TestCase):
    def test_type_key_writes_the_text(self) -> None:
        self.assertEqual(
            dictado.insert_command("type", "hola -- mundo"),
            [
                "xdotool", "type", "--clearmodifiers", "--delay", "5",
                "--", "hola -- mundo",
            ],
        )

    def test_other_keys_send_the_shortcut(self) -> None:
        self.assertEqual(
            dictado.insert_command("ctrl+shift+v", "hola"),
            ["xdotool", "key", "--clearmodifiers", "ctrl+shift+v"],
        )


if __name__ == "__main__":
    unittest.main()
