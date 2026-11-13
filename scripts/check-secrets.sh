#!/usr/bin/env bash
#
# check-secrets.sh — busca claves, correos y rutas personales antes de publicar.
#
# Uso:
#   bash scripts/check-secrets.sh
#
# Sale con código 0 si no encuentra nada sospechoso y 1 si hay hallazgos.
# No sustituye una revisión manual de `git diff`, pero evita los errores típicos.

set -uo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR" || exit 1

if [ -t 1 ]; then
  OK=$'\033[32m'; ERR=$'\033[31m'; WARN=$'\033[33m'; OFF=$'\033[0m'
else
  OK=""; ERR=""; WARN=""; OFF=""
fi

# Archivos a revisar: todo lo versionado si hay git, si no todo el árbol.
if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  mapfile -t FILES < <(git -C "$REPO_DIR" ls-files)
else
  mapfile -t FILES < <(find . -type f \
    -not -path './.git/*' \
    -not -path './.venv/*' \
    -not -name '*.pyc' \
    -not -name '*.wav' \
    | sed 's|^\./||' | sort)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No hay archivos que revisar."
  exit 0
fi

findings=0

report() {
  local label="$1"; shift
  local output
  output="$(grep -nIE "$@" "${FILES[@]}" 2>/dev/null || true)"
  if [ -n "$output" ] && [ "$label" = "correo electrónico" ]; then
    output="$(printf '%s\n' "$output" | grep -vE '@(example\.(com|org|net)|localhost)' || true)"
  fi
  if [ -n "$output" ]; then
    printf '%s✗ %s%s\n' "$ERR" "$label" "$OFF"
    printf '%s\n' "$output" | sed 's/^/    /'
    findings=$((findings + 1))
  fi
}

# Claves de Google (formato AIza...)
report "posible clave de API de Google" 'AIza[0-9A-Za-z_-]{20,}'

# Asignaciones con valor real a variables sensibles
report "asignación de GEMINI_API_KEY con valor" \
  'GEMINI_API_KEY[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9_-]{16,}'

# Claves privadas
report "bloque de clave privada" 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'

# Correos personales (se permiten example.com y similares)
report "correo electrónico" \
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# Rutas absolutas de un usuario concreto
report "ruta personal /home/<usuario>" '/home/[A-Za-z0-9._-]+/'

# Tokens de GitHub, AWS y similares
report "posible token de servicio" \
  '(gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})'

if [ "$findings" -eq 0 ]; then
  printf '%s✓ Sin claves, correos ni rutas personales evidentes (%d archivos).%s\n' \
    "$OK" "${#FILES[@]}" "$OFF"
  exit 0
fi

printf '\n%s%d grupo(s) de hallazgos.%s Revisa cada línea antes de publicar.\n' \
  "$WARN" "$findings" "$OFF"
exit 1
