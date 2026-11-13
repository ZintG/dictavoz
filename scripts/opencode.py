#!/usr/bin/env python3
"""Gestiona la integración opcional de dictado con opencode.

Solo modifica una configuración que ya exista: nunca crea `cli.json` ni su
directorio. Antes de cambiar `prompt.paste` guarda el estado anterior para
poder restaurarlo al desinstalar.

Uso:
    python3 scripts/opencode.py apply <cli.json> <copia.json> [--dry-run]
    python3 scripts/opencode.py revert <copia.json> [--dry-run]

Códigos de salida:
    0  cambio aplicado, revertido o innecesario
    2  no aplicable (no existe la configuración o no hay copia previa)
    3  estado inseguro o inválido; no se ha modificado nada
"""

from __future__ import annotations

import argparse
import json
import os
import stat
import sys
import tempfile
from pathlib import Path
from typing import Any

EXIT_OK = 0
EXIT_NOT_APPLICABLE = 2
EXIT_UNSAFE = 3

MISSING = object()


def read_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, data: Any, mode: int) -> None:
    """Escribe JSON de forma atómica conservando el modo indicado."""
    if path.is_symlink():
        path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def load_backup(path: Path) -> dict:
    data = read_json(path)
    if not isinstance(data, dict):
        raise ValueError("la copia no contiene un objeto JSON")
    target = data.get("path")
    if not isinstance(target, str) or not os.path.isabs(target):
        raise ValueError("la copia no contiene una ruta absoluta válida")
    if not isinstance(data.get("had_prompt"), bool):
        raise ValueError("la copia no indica si existía 'prompt'")
    if not isinstance(data.get("had_paste"), bool):
        raise ValueError("la copia no indica si existía 'prompt.paste'")
    if data["had_paste"] and "previous" not in data:
        raise ValueError("la copia no guarda el valor anterior")
    return data


def describe(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def apply(config_path: Path, backup_path: Path, dry_run: bool) -> int:
    if not config_path.is_file():
        print(f"no existe {config_path}; no se crea")
        return EXIT_NOT_APPLICABLE

    try:
        data = read_json(config_path)
    except OSError as exc:
        print(f"no se pudo leer {config_path}: {exc}")
        return EXIT_UNSAFE
    except ValueError as exc:
        print(f"{config_path} no contiene JSON válido: {exc}")
        return EXIT_UNSAFE

    if not isinstance(data, dict):
        print(f"{config_path} no contiene un objeto JSON")
        return EXIT_UNSAFE

    prompt_value = data.get("prompt", MISSING)
    if prompt_value is MISSING:
        had_prompt = False
        prompt: dict = {}
    elif isinstance(prompt_value, dict):
        had_prompt = True
        prompt = prompt_value
    else:
        print(f"{config_path}: 'prompt' no es un objeto; no se modifica")
        return EXIT_UNSAFE

    had_paste = "paste" in prompt
    previous = prompt.get("paste")

    backup = None
    if backup_path.exists():
        try:
            backup = load_backup(backup_path)
        except (OSError, ValueError) as exc:
            print(f"no se pudo leer la copia {backup_path}: {exc}")
            return EXIT_UNSAFE
        if Path(backup["path"]).resolve() != config_path.resolve():
            print(f"la copia {backup_path} pertenece a otra ruta; no se modifica")
            return EXIT_UNSAFE

    if previous == "full":
        print(f"{config_path}: prompt.paste ya es \"full\"; no hay cambios")
        return EXIT_OK

    if dry_run:
        print(f"pondría prompt.paste = \"full\" en {config_path}")
        return EXIT_OK

    if backup is None:
        backup_data = {
            "version": 1,
            "path": str(config_path.resolve()),
            "had_prompt": had_prompt,
            "had_paste": had_paste,
            "previous": previous,
        }
        try:
            write_json(backup_path, backup_data, 0o600)
        except OSError as exc:
            print(f"no se pudo guardar la copia {backup_path}: {exc}")
            return EXIT_UNSAFE

    prompt["paste"] = "full"
    data["prompt"] = prompt
    mode = stat.S_IMODE(config_path.stat().st_mode)
    try:
        write_json(config_path, data, mode)
    except OSError as exc:
        print(f"no se pudo escribir {config_path}: {exc}")
        return EXIT_UNSAFE

    before = describe(previous) if had_paste else "sin definir"
    print(f"opencode: prompt.paste = \"full\" en {config_path} (antes: {before})")
    return EXIT_OK


def revert(backup_path: Path, dry_run: bool) -> int:
    if not backup_path.is_file():
        print(f"no hay copia previa en {backup_path}; no se revierte")
        return EXIT_NOT_APPLICABLE

    try:
        backup = load_backup(backup_path)
    except (OSError, ValueError) as exc:
        print(f"no se pudo leer la copia {backup_path}: {exc}")
        return EXIT_UNSAFE

    target = Path(backup["path"])
    if not target.is_file():
        if dry_run:
            print(f"el archivo {target} ya no existe; se descartaría la copia")
            return EXIT_OK
        try:
            backup_path.unlink()
        except OSError as exc:
            print(f"no se pudo borrar la copia {backup_path}: {exc}")
            return EXIT_UNSAFE
        print(f"el archivo {target} ya no existe; se descarta la copia")
        return EXIT_OK

    try:
        data = read_json(target)
    except OSError as exc:
        print(f"no se pudo leer {target}: {exc}; se conserva la copia")
        return EXIT_UNSAFE
    except ValueError as exc:
        print(f"{target} no contiene JSON válido: {exc}; se conserva la copia")
        return EXIT_UNSAFE

    if not isinstance(data, dict):
        print(f"{target} no contiene un objeto JSON; se conserva la copia")
        return EXIT_UNSAFE

    prompt = data.get("prompt")
    if not isinstance(prompt, dict):
        print(f"{target}: 'prompt' no es un objeto; se conserva la copia")
        return EXIT_UNSAFE

    if prompt.get("paste") != "full":
        if dry_run:
            print(f"opencode cambió después de la instalación; se conservaría {target}")
            return EXIT_OK
        try:
            backup_path.unlink()
        except OSError as exc:
            print(f"no se pudo borrar la copia {backup_path}: {exc}")
            return EXIT_UNSAFE
        print(f"opencode cambió después de la instalación; se conserva {target}")
        return EXIT_OK

    if backup["had_paste"]:
        prompt["paste"] = backup["previous"]
        action = f"restaurado prompt.paste = {describe(backup['previous'])}"
    else:
        prompt.pop("paste", None)
        action = "eliminada la clave prompt.paste"

    if not backup["had_prompt"] and not prompt:
        data.pop("prompt", None)

    if dry_run:
        print(f"revertiría {target}: {action}")
        return EXIT_OK

    mode = stat.S_IMODE(target.stat().st_mode)
    try:
        write_json(target, data, mode)
    except OSError as exc:
        print(f"no se pudo escribir {target}: {exc}")
        return EXIT_UNSAFE

    try:
        backup_path.unlink()
    except OSError as exc:
        print(f"revertido {target}, pero no se pudo borrar {backup_path}: {exc}")
        return EXIT_UNSAFE

    print(f"opencode: {action} en {target}")
    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Integración opcional con opencode")
    sub = parser.add_subparsers(dest="action", required=True)

    apply_parser = sub.add_parser("apply", help="activa prompt.paste = full")
    apply_parser.add_argument("config", type=Path)
    apply_parser.add_argument("backup", type=Path)
    apply_parser.add_argument("--dry-run", action="store_true")

    revert_parser = sub.add_parser("revert", help="restaura el estado anterior")
    revert_parser.add_argument("backup", type=Path)
    revert_parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args(argv)
    if args.action == "apply":
        return apply(args.config, args.backup, args.dry_run)
    return revert(args.backup, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
