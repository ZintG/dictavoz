#!/usr/bin/env bash
#
# Pruebas del gestor de atajos con un gsettings falso.
#
# No toca la configuración real del escritorio: crea un binario `gsettings`
# temporal que guarda los valores en un directorio del propio test.
#
#   bash tests/test_hotkey.sh

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOTKEY="$REPO_DIR/scripts/hotkey.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state"

cat > "$TMP/bin/gsettings" <<'FAKE'
#!/usr/bin/env bash
# gsettings falso: guarda cada valor en un archivo y devuelve los valores
# por defecto habituales cuando la clave no existe.
set -euo pipefail
state="${FAKE_GSETTINGS_DIR:?}"
mkdir -p "$state"

sanitize() { printf '%s' "$1" | tr '/:|' '____'; }

op="${1:-}"
[ $# -gt 0 ] && shift

case "$op" in
  get|set|reset)
    schema="${1:-}"; key="${2:-}"; shift 2 || true
    value="${1:-}"
    file="$state/$(sanitize "$schema")__$(sanitize "$key")"
    case "$op" in
      get)
        if [ "${FAKE_FAIL_GET:-0}" = "1" ]; then
          echo "error simulado de lectura" >&2
          exit 1
        fi
        if [ -f "$file" ]; then
          case "$key" in
            name|command) printf "'%s'" "$(cat "$file")" ;;
            custom-list|custom-keybindings)
              if [ "$(cat "$file")" = "[]" ]; then printf '%s' '@as []'; else cat "$file"; fi
              ;;
            *) cat "$file" ;;
          esac
        else
          case "$key" in
            custom-list|custom-keybindings) printf '%s' '@as []' ;;
            binding) printf '%s' "['']" ;;
            *) printf '%s' "''" ;;
          esac
        fi
        ;;
      set)
        printf '%s' "$value" > "$file"
        ;;
      reset)
        rm -f "$file"
        ;;
    esac
    ;;
  list-schemas)
    exit 0
    ;;
  *)
    echo "operación no soportada: $op" >&2
    exit 1
    ;;
esac
FAKE
chmod +x "$TMP/bin/gsettings"

export PATH="$TMP/bin:$PATH"
export FAKE_GSETTINGS_DIR="$TMP/state"
export XDG_CURRENT_DESKTOP="X-Cinnamon"
export DESKTOP_SESSION="cinnamon"

DICTADO_BIN="$TMP/instalacion/bin/dictado"
export DICTADO_BIN

fallos=0
comprobar() {
  local descripcion="$1" esperado="$2" obtenido="$3"
  if [ "$esperado" = "$obtenido" ]; then
    printf '  ✓ %s\n' "$descripcion"
  else
    printf '  ✗ %s\n    esperaba: %s\n    obtuve:   %s\n' \
      "$descripcion" "$esperado" "$obtenido" >&2
    fallos=$((fallos + 1))
  fi
}

lista() { gsettings get org.cinnamon.desktop.keybindings custom-list; }
comando() { gsettings get "org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$1/" command; }
binding() { gsettings get "org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$1/" binding; }

echo "Pruebas del gestor de atajos"

# 1. Primera instalación
bash "$HOTKEY" set "Ctrl+Alt+D" >/dev/null
comprobar "crea custom0" "['custom0']" "$(lista)"
comprobar "guarda el comando" "'$DICTADO_BIN toggle'" "$(comando custom0)"
comprobar "convierte la combinación" "['<Control><Alt>d']" "$(binding custom0)"

# 2. Cambiar el atajo reutiliza la entrada
bash "$HOTKEY" set "Ctrl+Shift+Space" >/dev/null
comprobar "no duplica la entrada" "['custom0']" "$(lista)"
comprobar "actualiza la combinación" "['<Control><Shift>space']" "$(binding custom0)"

# 3. Estado
if bash "$HOTKEY" status >/dev/null; then
  comprobar "status encuentra el atajo" "0" "0"
else
  comprobar "status encuentra el atajo" "0" "1"
fi

# 4. Otro prefijo no debe tocar el atajo instalado
otro="$TMP/otro/bin/dictado"
if DICTADO_BIN="$otro" bash "$HOTKEY" status >/dev/null 2>&1; then
  comprobar "status ignora otro prefijo" "1" "0"
else
  comprobar "status ignora otro prefijo" "1" "1"
fi
DICTADO_BIN="$otro" bash "$HOTKEY" remove >/dev/null 2>&1 || true
comprobar "remove de otro prefijo conserva la lista" "['custom0']" "$(lista)"

# 5. Un atajo ajeno previo se conserva y dictado usa el siguiente hueco
export DICTADO_BIN="/opt/otra-herramienta/bin/app"
bash "$HOTKEY" set "Ctrl+Alt+J" >/dev/null
export DICTADO_BIN="$TMP/instalacion/bin/dictado"
bash "$HOTKEY" set "Ctrl+Alt+D" >/dev/null
comprobar "conserva el atajo ajeno" "['custom0', 'custom1']" "$(lista)"
comprobar "el atajo ajeno sigue intacto" "'/opt/otra-herramienta/bin/app toggle'" "$(comando custom0)"
comprobar "dictado ocupa el hueco libre" "'$DICTADO_BIN toggle'" "$(comando custom1)"

# 6. Eliminar solo dictado
bash "$HOTKEY" remove >/dev/null
comprobar "elimina solo su entrada" "['custom0']" "$(lista)"
comprobar "el atajo ajeno sobrevive" "'/opt/otra-herramienta/bin/app toggle'" "$(comando custom0)"

# 7. Un fallo de lectura no debe vaciar la lista
antes="$(lista)"
if FAKE_FAIL_GET=1 bash "$HOTKEY" remove >/dev/null 2>&1; then
  comprobar "fallo de lectura devuelve error" "1" "0"
else
  comprobar "fallo de lectura devuelve error" "1" "1"
fi
comprobar "fallo de lectura no toca la lista" "$antes" "$(lista)"

# 8. Eliminar deja la lista vacía cuando corresponde
export DICTADO_BIN="/opt/otra-herramienta/bin/app"
bash "$HOTKEY" remove >/dev/null
comprobar "remove deja la lista vacía" "@as []" "$(lista)"

# 9. KDE convierte correctamente teclas con nombre
mkdir -p "$TMP/kde-bin" "$TMP/kde-home"
cat > "$TMP/kde-bin/kwriteconfig6" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_KDE_LOG:?}"
if [[ " $* " == *" --print "* ]]; then
  if [ "${FAKE_KDE_EMPTY:-0}" = "1" ]; then
    exit 0
  fi
  printf '%s\n' "Ctrl+Shift+Space,none,Dictado"
fi
FAKE
chmod +x "$TMP/kde-bin/kwriteconfig6"
export HOME="$TMP/kde-home"
export FAKE_KDE_LOG="$TMP/kde.log"
export XDG_CURRENT_DESKTOP="KDE"
export DESKTOP_SESSION="plasma"
export DICTADO_BIN="$TMP/instalacion/bin/dictado"

if PATH="$TMP/kde-bin:$PATH" bash "$HOTKEY" set "Ctrl+Shift+Space" >/dev/null; then
  if grep -q 'Ctrl+Shift+Space' "$TMP/kde.log"; then
    comprobar "KDE convierte Space" "0" "0"
  else
    comprobar "KDE convierte Space" "0" "1"
  fi
else
  comprobar "KDE convierte Space" "0" "1"
fi

if PATH="$TMP/kde-bin:$PATH" bash "$HOTKEY" status >/dev/null 2>&1; then
  comprobar "KDE status con binding" "0" "0"
else
  comprobar "KDE status con binding" "0" "1"
fi

if FAKE_KDE_EMPTY=1 PATH="$TMP/kde-bin:$PATH" bash "$HOTKEY" status >/dev/null 2>&1; then
  comprobar "KDE status sin binding" "1" "0"
else
  comprobar "KDE status sin binding" "1" "1"
fi

# 10. Un escritorio sin soporte no debe fingir éxito
mkdir -p "$TMP/min-bin"
ln -s "$(command -v bash)" "$TMP/min-bin/bash"
ln -s "$(command -v cat)" "$TMP/min-bin/cat"
if env PATH="$TMP/min-bin" HOME="$TMP/kde-home" XDG_CURRENT_DESKTOP="MATE" \
  DESKTOP_SESSION="mate" DICTADO_BIN="$TMP/instalacion/bin/dictado" \
  "$(command -v bash)" "$HOTKEY" set "Ctrl+Alt+D" >/dev/null 2>&1; then
  comprobar "manual_help devuelve error" "1" "0"
else
  comprobar "manual_help devuelve error" "1" "1"
fi

echo
if [ "$fallos" -eq 0 ]; then
  echo "Todas las pruebas del atajo pasaron."
  exit 0
fi
echo "$fallos prueba(s) fallaron." >&2
exit 1
