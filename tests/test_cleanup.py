"""Pruebas de la limpieza por reglas y de la validación del pulido con LLM.

No necesitan red ni micrófono: solo importan bin/dictado como módulo.

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


def make_cfg(**overrides):
    """Copia de la configuración por defecto con ajustes puntuales."""
    import copy

    cfg = copy.deepcopy(dictado.DEFAULTS)
    for dotted, value in overrides.items():
        section, key = dotted.split("__")
        cfg[section][key] = value
    return cfg


class CleanRulesTest(unittest.TestCase):
    def setUp(self):
        self.cfg = make_cfg()

    def clean(self, text, cfg=None):
        return dictado.clean_rules(text, cfg or self.cfg)

    def test_remove_hard_fillers(self):
        self.assertEqual(
            self.clean("eh, o sea, abre el archivo ahora mismo en el editor"),
            "Abre el archivo ahora mismo en el editor.",
        )

    def test_remove_tag_question(self):
        self.assertEqual(
            self.clean("abre el archivo, ¿sabes?"),
            "Abre el archivo",
        )

    def test_collapse_repeated_word(self):
        self.assertEqual(
            self.clean("abre el el archivo"),
            "Abre el archivo",
        )

    def test_collapse_repeated_phrase(self):
        self.assertEqual(
            self.clean("un botón, un botón de login"),
            "Un botón de login",
        )

    def test_keeps_legitimate_comma_before_de(self):
        self.assertEqual(
            self.clean("Revisa el módulo, de hecho está roto"),
            "Revisa el módulo, de hecho está roto.",
        )

    def test_does_not_collapse_words_with_digits(self):
        self.assertEqual(self.clean("versión 1 1 5"), "Versión 1 1 5")
        self.assertEqual(self.clean("10 10 pesos"), "10 10 pesos")

    def test_keeps_esto_at_start(self):
        self.assertEqual(
            self.clean("Esto, por favor, revísalo"),
            "Esto, por favor, revísalo",
        )

    def test_removes_este_as_filler(self):
        self.assertEqual(
            self.clean("Hola, este, quiero que, añadas un botón"),
            "Hola, quiero que añadas un botón.",
        )

    def test_capitalize_after_period(self):
        self.assertEqual(
            self.clean("primera frase. segunda frase"),
            "Primera frase. Segunda frase",
        )

    def test_no_final_period_for_commands(self):
        self.assertEqual(
            self.clean("git status"),
            "git status",
        )

    def test_short_text_keeps_lowercase_without_forced_period(self):
        self.assertEqual(self.clean("hola"), "Hola")

    def test_rules_can_be_disabled(self):
        cfg = make_cfg(cleanup__rules=False)
        self.assertEqual(self.clean("  hola   mundo  ", cfg), "hola   mundo")

    def test_spaces_before_punctuation(self):
        self.assertEqual(
            self.clean("abre el archivo , luego guárdalo"),
            "Abre el archivo, luego guárdalo",
        )


class ShouldPolishTest(unittest.TestCase):
    def setUp(self):
        self.cfg = make_cfg()

    def test_short_text_is_not_polished(self):
        self.assertFalse(dictado.should_polish("hola mundo", self.cfg))

    def test_long_text_is_polished(self):
        text = "palabra " * 40
        self.assertTrue(dictado.should_polish(text, self.cfg))

    def test_many_sentences_are_polished(self):
        self.assertTrue(dictado.should_polish("Una. Dos. Tres.", self.cfg))

    def test_disabled_llm_never_polishes(self):
        cfg = make_cfg(cleanup__llm=False)
        self.assertFalse(dictado.should_polish("palabra " * 40, cfg))

    def test_residual_repetition_triggers_polish(self):
        self.assertTrue(dictado.should_polish("esto esto es una prueba", self.cfg))


class ValidPolishTest(unittest.TestCase):
    def setUp(self):
        self.cfg = make_cfg()
        self.original = "abre el archivo src/app.ts y ejecuta el comando --verbose"

    def test_accepts_good_candidate(self):
        ok, result = dictado.valid_polish(
            self.original,
            "Abre el archivo src/app.ts y ejecuta el comando --verbose.",
            self.cfg,
        )
        self.assertTrue(ok, result)

    def test_rejects_empty(self):
        ok, reason = dictado.valid_polish(self.original, "   ", self.cfg)
        self.assertFalse(ok)
        self.assertIn("vacía", reason)

    def test_rejects_preamble(self):
        ok, reason = dictado.valid_polish(
            self.original,
            "Aquí tienes el texto: abre el archivo src/app.ts y ejecuta --verbose",
            self.cfg,
        )
        self.assertFalse(ok)
        self.assertIn("explicación", reason)

    def test_rejects_fenced_code(self):
        ok, reason = dictado.valid_polish(
            self.original,
            "```\nabre src/app.ts --verbose\n```",
            self.cfg,
        )
        self.assertFalse(ok)
        self.assertIn("código", reason)

    def test_rejects_too_short(self):
        ok, reason = dictado.valid_polish(self.original, "Abre el archivo.", self.cfg)
        self.assertFalse(ok)
        self.assertIn("longitud", reason)

    def test_rejects_lost_technical_token(self):
        ok, reason = dictado.valid_polish(
            self.original,
            "Abre el archivo y ejecuta el comando con la opción indicada.",
            self.cfg,
        )
        self.assertFalse(ok)
        self.assertIn("términos técnicos", reason)


class TechTokensTest(unittest.TestCase):
    def test_detects_paths_flags_and_filenames(self):
        tokens = dictado.tech_tokens(
            "edita src/app.ts, pasa --verbose y mira config.toml"
        )
        self.assertIn("src/app.ts", tokens)
        self.assertIn("--verbose", tokens)
        self.assertIn("config.toml", tokens)

    def test_detects_camel_case_and_snake_case(self):
        tokens = dictado.tech_tokens("usa getUserName y mi_variable")
        self.assertIn("getUserName", tokens)
        self.assertIn("mi_variable", tokens)


class HelpersTest(unittest.TestCase):
    def test_collapse_phrase_repeats_keeps_single(self):
        self.assertEqual(
            dictado.collapse_phrase_repeats("hola mundo hola mundo"),
            "hola mundo",
        )

    def test_collapse_phrase_repeats_ignores_words_with_digits(self):
        self.assertEqual(
            dictado.collapse_phrase_repeats("10 20 10 20"),
            "10 20 10 20",
        )

    def test_count_sentences(self):
        self.assertEqual(dictado.count_sentences("Una. Dos! ¿Tres?"), 3)

    def test_capitalize(self):
        self.assertEqual(
            dictado.capitalize("hola. adiós"), "Hola. Adiós"
        )


if __name__ == "__main__":
    unittest.main()
