#!/usr/bin/env bash
#
# install.sh — instalador de dictado para Linux.
#
# Instala el ejecutable, la configuración de ejemplo, el gestor de atajos y,
# opcionalmente, la integración con opencode. No necesita privilegios de root
# salvo para instalar dependencias del sistema con el gestor de paquetes.
#
# Uso:
#   ./install.sh                        instalación interactiva (recomendada)
#   ./install.sh --prefix ~/.local      cambia el directorio de instalación
#   ./install.sh --hotkey "Ctrl+Alt+D"  cambia el atajo global
#   ./install.sh --non-interactive      sin preguntas (usa GEMINI_API_KEY)
#   ./install.sh --dry-run              muestra lo que haría y sale
#   ./install.sh --no-deps              no instala paquetes del sistema
#   ./install.sh --no-hotkey            no configura el atajo global
#   ./install.sh --no-opencode          no modifica ni revierte opencode
#   ./install.sh --uninstall            desinstala (conserva tus datos)
#   ./install.sh --uninstall --purge    desinstala y borra también tus datos
#
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$REPO_DIR/VERSION" 2>/dev/null || echo "desconocida")"

PREFIX="${PREFIX:-$HOME/.local}"
HOTKEY="Ctrl+Alt+D"
HOTKEY_SET=0
INTERACTIVE=1
DRY_RUN=0
WITH_DEPS=1
WITH_HOTKEY=1
WITH_OPENCODE=1
ACTION="install"
PURGE=0
API_KEY="${GEMINI_API_KEY:-}"

# --------------------------------------------------------------------------
# Salida
# --------------------------------------------------------------------------

if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'
  OK=$'\033[32m'; WARN=$'\033[33m'; ERR=$'\033[31m'; OFF=$'\033[0m'
else
  BOLD=""; DIM=""; OK=""; WARN=""; ERR=""; OFF=""
fi

step_no=0
step()  { step_no=$((step_no + 1)); printf '\n%s[%d/7]%s %s%s%s\n' "$BOLD" "$step_no" "$OFF" "$BOLD" "$*" "$OFF"; }
ok()    { printf '  %s✓%s %s\n' "$OK" "$OFF" "$*"; }
info()  { printf '  %s·%s %s\n' "$DIM" "$OFF" "$*"; }
warn()  { printf '  %s!%s %s\n' "$WARN" "$OFF" "$*"; }
err()   { printf '  %s✗%s %s\n' "$ERR" "$OFF" "$*" >&2; }
die()   { err "$*"; exit 1; }

# Aplica o revierte la integración con opencode mostrando el resultado.
# El helper devuelve 2 cuando no hay nada que hacer y 3 cuando es inseguro.
run_opencode_helper() {
  local output status
  if output="$("$PYTHON" "$OPENCODE_HELPER" "$@" 2>&1)"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "$output"
    else
      ok "$output"
    fi
  else
    status=$?
    case "$status" in
      2) info "$output" ;;
      *) warn "$output" ;;
    esac
  fi
}

# Ejecuta un comando como root si hace falta, respetando --dry-run.
run_root() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "ejecutaría: $*"
    return 0
  fi
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# --------------------------------------------------------------------------
# Argumentos
# --------------------------------------------------------------------------

usage() {
  cat <<'EOF'
install.sh — instalador de dictado para Linux.

Instala el ejecutable, la configuración de ejemplo, el gestor de atajos y,
opcionalmente, la integración con opencode. No necesita privilegios de root
salvo para instalar dependencias del sistema con el gestor de paquetes.

Uso:
  ./install.sh                        instalación interactiva (recomendada)
  ./install.sh --prefix ~/.local      cambia el directorio de instalación
  ./install.sh --hotkey "Ctrl+Alt+D"  cambia el atajo global
  ./install.sh --non-interactive      sin preguntas (usa GEMINI_API_KEY)
  ./install.sh --dry-run              muestra lo que haría y sale
  ./install.sh --no-deps              no instala paquetes del sistema
  ./install.sh --no-hotkey            no configura el atajo global
  ./install.sh --no-opencode          no modifica ni revierte opencode
  ./install.sh --uninstall            desinstala (conserva tus datos)
  ./install.sh --uninstall --purge    desinstala y borra también tus datos
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)          PREFIX="${2:?falta el valor de --prefix}"; shift 2 ;;
    --prefix=*)        PREFIX="${1#*=}"; shift ;;
    --hotkey)          HOTKEY="${2:?falta el valor de --hotkey}"; HOTKEY_SET=1; shift 2 ;;
    --hotkey=*)        HOTKEY="${1#*=}"; HOTKEY_SET=1; shift ;;
    --non-interactive) INTERACTIVE=0; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    --no-deps)         WITH_DEPS=0; shift ;;
    --no-hotkey)       WITH_HOTKEY=0; shift ;;
    --no-opencode)     WITH_OPENCODE=0; shift ;;
    --uninstall)       ACTION="uninstall"; shift ;;
    --purge)           PURGE=1; shift ;;
    -h|--help)         usage ;;
    *)                 die "opción desconocida: $1 (usa --help)" ;;
  esac
done

if [ "$PURGE" -eq 1 ] && [ "$ACTION" != "uninstall" ]; then
  die "--purge solo tiene sentido junto con --uninstall"
fi

PREFIX="${PREFIX/#\~/$HOME}"
PREFIX="$(cd -- "$PREFIX" 2>/dev/null && pwd || printf '%s' "$PREFIX")"
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib/dictado"
DICTADO_BIN="$BIN_DIR/dictado"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
case "$CONFIG_HOME" in /*) ;; *) CONFIG_HOME="$HOME/.config" ;; esac
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
case "$STATE_HOME" in /*) ;; *) STATE_HOME="$HOME/.local/state" ;; esac

CONFIG_DIR="$CONFIG_HOME/dictado"
CONFIG_FILE="$CONFIG_DIR/config.toml"
ENV_FILE="$CONFIG_DIR/env"
DATA_DIR="$STATE_HOME/dictado"
CLI_JSON="$CONFIG_HOME/opencode/cli.json"
OPENCODE_BACKUP="$CONFIG_DIR/opencode-backup.json"
OPENCODE_HELPER="$REPO_DIR/scripts/opencode.py"

# Disponible también durante la desinstalación, que ocurre antes del paso 1.
PYTHON="${PYTHON:-$(command -v python3 || true)}"

# --------------------------------------------------------------------------
# Desinstalación
# --------------------------------------------------------------------------

if [ "$ACTION" = "uninstall" ]; then
  printf '%sDesinstalando dictado %s%s\n' "$BOLD" "$VERSION" "$OFF"

  if [ "$WITH_OPENCODE" -eq 1 ]; then
    if [ -n "$PYTHON" ] && [ -f "$OPENCODE_HELPER" ]; then
      opencode_args=(revert "$OPENCODE_BACKUP")
      if [ "$DRY_RUN" -eq 1 ]; then opencode_args+=(--dry-run); fi
      run_opencode_helper "${opencode_args[@]}"
    else
      info "no se revierte opencode (falta python3 o scripts/opencode.py)"
    fi
  else
    info "opencode: se conserva la configuración (--no-opencode)"
    if [ "$PURGE" -eq 1 ]; then
      warn "con --purge también se borrará la copia de opencode"
    fi
  fi

  if [ -f "$LIB_DIR/hotkey.sh" ] && [ "$WITH_HOTKEY" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    DICTADO_BIN="$DICTADO_BIN" bash "$LIB_DIR/hotkey.sh" remove 2>/dev/null || true
  fi

  for path in "$DICTADO_BIN" "$LIB_DIR/hotkey.sh"; do
    if [ -e "$path" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then info "borraría $path"
      else rm -f "$path" && ok "eliminado $path"; fi
    fi
  done
  if [ -d "$LIB_DIR" ] && [ "$DRY_RUN" -eq 0 ]; then
    rmdir "$LIB_DIR" 2>/dev/null || true
  fi

  if [ "$PURGE" -eq 1 ]; then
    for path in "$CONFIG_DIR" "$DATA_DIR"; do
      if [ -e "$path" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then info "borraría $path"
        else rm -rf "$path" && ok "borrado $path"; fi
      fi
    done
  else
    info "se conservan $CONFIG_DIR y $DATA_DIR (usa --purge para borrarlos)"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\n%sSimulación completada: no se ha cambiado nada.%s\n' "$OK" "$OFF"
  else
    printf '\n%sDictado desinstalado.%s\n' "$OK" "$OFF"
  fi
  exit 0
fi

# --------------------------------------------------------------------------
# Paso 1: comprobar el sistema
# --------------------------------------------------------------------------

step "Comprobando el sistema"

[ -f "$REPO_DIR/bin/dictado" ] || die "no encuentro bin/dictado; ejecuta este script desde el repositorio"
[ -f "$REPO_DIR/scripts/hotkey.sh" ] || die "no encuentro scripts/hotkey.sh"

if [ "$(id -u)" -eq 0 ]; then
  warn "estás ejecutando como root; la instalación irá a $PREFIX"
fi

PYTHON="${PYTHON:-$(command -v python3 || true)}"
[ -n "$PYTHON" ] || die "falta python3; instálalo y vuelve a intentarlo"
PY_VERSION="$("$PYTHON" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
ok "Python $PY_VERSION en $PYTHON"

if ! "$PYTHON" -c 'import tomllib' 2>/dev/null && ! "$PYTHON" -c 'import tomli' 2>/dev/null; then
  NEED_TOMLI=1
else
  NEED_TOMLI=0
fi

SESSION="${XDG_SESSION_TYPE:-}"
if [ -z "$SESSION" ]; then
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then SESSION="wayland"; else SESSION="x11"; fi
fi
if [ "$SESSION" = "wayland" ]; then
  info "sesión Wayland: el texto se copiará al portapapeles, sin pegado automático"
else
  ok "sesión X11: pegado automático disponible"
fi

DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-desconocido}}"
ok "escritorio: $DESKTOP"

# Gestor de paquetes
PM=""
if command -v apt-get >/dev/null 2>&1; then PM="apt"
elif command -v dnf >/dev/null 2>&1; then PM="dnf"
elif command -v pacman >/dev/null 2>&1; then PM="pacman"
elif command -v zypper >/dev/null 2>&1; then PM="zypper"
elif command -v apk >/dev/null 2>&1; then PM="apk"
fi
if [ -n "$PM" ]; then ok "gestor de paquetes: $PM"; else warn "no reconozco el gestor de paquetes"; fi

# --------------------------------------------------------------------------
# Paso 2: dependencias
# --------------------------------------------------------------------------

step "Instalando dependencias"

if [ "$WITH_DEPS" -eq 0 ]; then
  info "omitido (--no-deps)"
else
  BASE_PKGS=()
  case "$PM" in
    apt)    BASE_PKGS=(alsa-utils ffmpeg x11-utils xclip xdotool libnotify-bin) ;;
    dnf)    BASE_PKGS=(alsa-utils ffmpeg xprop xclip xdotool libnotify) ;;
    pacman) BASE_PKGS=(alsa-utils ffmpeg xorg-xprop xclip xdotool libnotify) ;;
    zypper) BASE_PKGS=(alsa-utils ffmpeg xprop xclip xdotool libnotify-tools) ;;
    apk)    BASE_PKGS=(alsa-utils ffmpeg xprop xclip xdotool libnotify) ;;
  esac

  if [ "$SESSION" = "wayland" ]; then
    case "$PM" in
      apt)    BASE_PKGS+=(wl-clipboard) ;;
      dnf|pacman|zypper|apk) BASE_PKGS+=(wl-clipboard) ;;
    esac
  fi
  if [ "$NEED_TOMLI" -eq 1 ]; then
    case "$PM" in
      apt)    BASE_PKGS+=(python3-tomli) ;;
      dnf)    BASE_PKGS+=(python3-tomli) ;;
      pacman) BASE_PKGS+=(python-tomli) ;;
      zypper) BASE_PKGS+=(python3-tomli) ;;
      apk)    BASE_PKGS+=(py3-tomli) ;;
      *)      : ;;
    esac
  fi

  # Comprueba qué falta de verdad
  MISSING=()
  for pkg in "${BASE_PKGS[@]:-}"; do
    [ -n "$pkg" ] || continue
    MISSING+=("$pkg")
  done

  if [ "$PM" = "apt" ]; then
    # En apt conviene actualizar el índice antes de instalar
    info "actualizando el índice de paquetes"
    run_root apt-get update -qq || warn "apt-get update falló; sigo con el índice actual"
    info "instalando: ${MISSING[*]}"
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING[@]}" \
      || warn "algunas dependencias no se instalaron; revisa los mensajes de arriba"
  elif [ -n "$PM" ]; then
    info "instalando: ${MISSING[*]}"
    case "$PM" in
      dnf)    run_root dnf install -y "${MISSING[@]}" ;;
      pacman) run_root pacman -S --needed --noconfirm "${MISSING[@]}" ;;
      zypper) run_root zypper --non-interactive install "${MISSING[@]}" ;;
      apk)    run_root apk add "${MISSING[@]}" ;;
    esac || warn "algunas dependencias no se instalaron; revisa los mensajes de arriba"
  else
    warn "instala manualmente: ${MISSING[*]}"
  fi

  # Verificación final
  if [ "$NEED_TOMLI" -eq 1 ]; then
    if "$PYTHON" -c 'import tomli' 2>/dev/null; then
      ok "tomli disponible"
    else
      warn "falta tomli: instala python3-tomli (o usa Python 3.11+)"
    fi
  fi
  for binary in arecord notify-send; do
    if command -v "$binary" >/dev/null 2>&1; then ok "$binary disponible"
    else warn "falta $binary"; fi
  done
  for binary in ffmpeg xclip xdotool xprop wl-copy; do
    if command -v "$binary" >/dev/null 2>&1; then ok "$binary disponible"
    else info "$binary no está (opcional según la sesión)"; fi
  done
fi

# --------------------------------------------------------------------------
# Paso 3: archivos
# --------------------------------------------------------------------------

step "Instalando archivos en $PREFIX"

if [ "$DRY_RUN" -eq 1 ]; then
  info "crearía $BIN_DIR y $LIB_DIR"
  info "copiaría bin/dictado → $DICTADO_BIN"
  info "copiaría scripts/hotkey.sh → $LIB_DIR/hotkey.sh"
else
  mkdir -p "$BIN_DIR" "$LIB_DIR"
  install -m 755 "$REPO_DIR/bin/dictado" "$DICTADO_BIN"
  install -m 755 "$REPO_DIR/scripts/hotkey.sh" "$LIB_DIR/hotkey.sh"
  ok "ejecutable: $DICTADO_BIN"
  ok "atajos:     $LIB_DIR/hotkey.sh"
fi

# PATH
case ":$PATH:" in
  *":$BIN_DIR:"*) ok "$BIN_DIR ya está en PATH" ;;
  *)
    warn "$BIN_DIR no está en PATH"
    info "añade esta línea a tu ~/.profile o ~/.bashrc:"
    info "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

# --------------------------------------------------------------------------
# Paso 4: clave de API
# --------------------------------------------------------------------------

step "Configurando la clave de Gemini"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR" 2>/dev/null || true
fi

KEY_VALID=0
if [ -n "$API_KEY" ]; then
  if printf '%s' "$API_KEY" | grep -Eq '^AIza[0-9A-Za-z_-]{20,}$'; then
    KEY_VALID=1
    ok "clave recibida por la variable GEMINI_API_KEY"
  else
    warn "GEMINI_API_KEY no tiene el formato esperado (AIza...); se ignora"
    API_KEY=""
  fi
elif [ -s "$ENV_FILE" ] && grep -q '^GEMINI_API_KEY=.' "$ENV_FILE"; then
  chmod 600 "$ENV_FILE" 2>/dev/null || true
  ok "ya existe una clave en $ENV_FILE"
  KEY_VALID=1
fi

if [ "$KEY_VALID" -eq 0 ]; then
  if [ "$INTERACTIVE" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    cat <<'EOF'

  Necesitas una clave gratuita de Google AI Studio:
    1. Abre https://aistudio.google.com/apikey
    2. Inicia sesión con tu cuenta de Google
    3. Pulsa "Create API key" y copia el valor (empieza por AIza)

  La clave se guarda solo en tu equipo, en un archivo con permisos 600,
  y nunca se envía a ningún sitio que no sea la API de Gemini.

EOF
    printf '  Pega la clave (no se mostrará) y pulsa Enter: '
    if [ -t 0 ]; then
      IFS= read -rs API_KEY || true
      printf '\n'
    elif [ -r /dev/tty ]; then
      IFS= read -rs API_KEY < /dev/tty || true
      printf '\n'
    fi
    API_KEY="$(printf '%s' "$API_KEY" | tr -d '[:space:]')"

    if [ -z "$API_KEY" ]; then
      warn "no se introdujo ninguna clave"
      info "puedes configurarla después con: dictado config set-key"
    elif ! printf '%s' "$API_KEY" | grep -Eq '^AIza[0-9A-Za-z_-]{20,}$'; then
      warn "el formato no parece correcto (debería empezar por AIza)"
      info "no se ha guardado; usa después: dictado config set-key"
      API_KEY=""
    else
      KEY_VALID=1
    fi
  else
    warn "sin clave de API (modo no interactivo)"
    info "configúrala después con: dictado config set-key"
    info "o exporta GEMINI_API_KEY antes de ejecutar el instalador"
  fi
fi

if [ "$KEY_VALID" -eq 1 ] && [ -n "$API_KEY" ] && [ "$DRY_RUN" -eq 0 ]; then
  umask 077
  {
    printf '# Clave de API de Gemini. No compartas este archivo.\n'
    printf 'GEMINI_API_KEY=%s\n' "$API_KEY"
  } > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  ok "clave guardada en $ENV_FILE (permisos 600)"
fi

# --------------------------------------------------------------------------
# Paso 5: configuración
# --------------------------------------------------------------------------

step "Creando la configuración"

if [ -f "$CONFIG_FILE" ]; then
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
  ok "ya existe $CONFIG_FILE (no se sobrescribe)"
  info "para verla o editarla: dictado config show | dictado config edit"
else
  if [ "$DRY_RUN" -eq 1 ]; then
    info "crearía $CONFIG_FILE desde config/config.example.toml"
  else
    mkdir -p "$CONFIG_DIR"
    cp "$REPO_DIR/config/config.example.toml" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    ok "creada $CONFIG_FILE"
    info "revísala y ajusta el idioma, el micrófono y el vocabulario"
  fi
fi

# --------------------------------------------------------------------------
# Paso 6: atajo de teclado
# --------------------------------------------------------------------------

step "Configurando el atajo global ($HOTKEY)"

if [ "$WITH_HOTKEY" -eq 0 ]; then
  info "omitido (--no-hotkey)"
else
  if [ "$INTERACTIVE" -eq 1 ] && [ "$HOTKEY_SET" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    printf '  Atajo global [%s]: ' "$HOTKEY"
    respuesta=""
    if [ -t 0 ]; then
      IFS= read -r respuesta || true
    elif [ -r /dev/tty ]; then
      IFS= read -r respuesta < /dev/tty || true
    fi
    respuesta="$(printf '%s' "$respuesta" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "$respuesta" ]; then
      HOTKEY="$respuesta"
    fi
    info "se usará $HOTKEY"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    info "registraría $HOTKEY → $DICTADO_BIN toggle"
  elif DICTADO_BIN="$DICTADO_BIN" bash "$LIB_DIR/hotkey.sh" set "$HOTKEY" \
    && DICTADO_BIN="$DICTADO_BIN" bash "$LIB_DIR/hotkey.sh" status >/dev/null; then
    ok "atajo listo: pulsa $HOTKEY para empezar o parar de dictar"
  else
    warn "no se pudo registrar el atajo automáticamente"
    info "asígnalo a mano a este comando: $DICTADO_BIN toggle"
  fi
fi

# --------------------------------------------------------------------------
# Paso 7: opencode y diagnóstico
# --------------------------------------------------------------------------

step "Integración con opencode y diagnóstico"

if [ "$WITH_OPENCODE" -eq 0 ]; then
  info "omitido (--no-opencode)"
elif [ ! -f "$CLI_JSON" ]; then
  info "opencode sin configuración; no se crea ($CLI_JSON)"
  info "si quieres integrarlo, añade a mano: { \"prompt\": { \"paste\": \"full\" } }"
elif [ ! -f "$OPENCODE_HELPER" ] || [ -z "$PYTHON" ]; then
  warn "no se modificó opencode (falta python3 o scripts/opencode.py)"
else
  opencode_args=(apply "$CLI_JSON" "$OPENCODE_BACKUP")
  if [ "$DRY_RUN" -eq 1 ]; then opencode_args+=(--dry-run); fi
  run_opencode_helper "${opencode_args[@]}"
fi

if [ "$DRY_RUN" -eq 0 ] && [ -x "$DICTADO_BIN" ]; then
  printf '\n'
  "$DICTADO_BIN" doctor || true
fi

# --------------------------------------------------------------------------
# Resumen
# --------------------------------------------------------------------------

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n%sSimulación completada: no se ha cambiado nada.%s\n' "$OK" "$OFF"
  printf 'Quita --dry-run para instalar de verdad.\n'
  exit 0
fi

if [ "$SESSION" = "wayland" ]; then
  INSERT_LINE="  el texto se copia al portapapeles; pégalo con Ctrl+V."
else
  INSERT_LINE="  el texto se copia y se pega en la ventana donde estabas."
fi

cat <<EOF

${BOLD}${OK}Dictado $VERSION instalado.${OFF}

  Pulsa ${BOLD}$HOTKEY${OFF} y habla. Vuelve a pulsarlo para parar:
$INSERT_LINE

  Comandos útiles:
    dictado doctor              diagnóstico completo
    dictado status              ¿está grabando?
    dictado config show         ver la configuración
    dictado config edit         editarla con tu editor
    dictado config set-key      cambiar la clave de API
    dictado hotkey set "Ctrl+Alt+D"   cambiar el atajo
    dictado history             últimos dictados
    dictado purge               borrar historial y audio

  Documentación: $REPO_DIR/README.md
  Desinstalar:   $REPO_DIR/install.sh --uninstall

EOF
