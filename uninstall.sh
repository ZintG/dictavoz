#!/usr/bin/env bash
#
# uninstall.sh — atajo para desinstalar dictado.
#
# Equivale a: ./install.sh --uninstall
#
# Uso:
#   ./uninstall.sh              quita el programa y el atajo, conserva tus datos
#   ./uninstall.sh --purge      borra también configuración e historial
#   ./uninstall.sh --no-opencode conserva la configuración de opencode
#   ./uninstall.sh --prefix DIR desinstala de un prefijo distinto de ~/.local
#
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$REPO_DIR/install.sh" --uninstall "$@"
