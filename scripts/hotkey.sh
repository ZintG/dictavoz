#!/usr/bin/env bash
#
# hotkey.sh — registra el atajo global de dictado en distintos escritorios.
#
# Uso:
#   hotkey.sh set [combinación]    crea o actualiza el atajo
#   hotkey.sh status               muestra el atajo configurado
#   hotkey.sh remove               elimina el atajo
#
# Variables:
#   DICTADO_BIN   ruta al ejecutable (por defecto: el que esté en PATH)
#
set -euo pipefail

DEFAULT_COMBO="<Control><Alt>d"
DICTADO_BIN="${DICTADO_BIN:-$(command -v dictado 2>/dev/null || echo "$HOME/.local/bin/dictado")}"

# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_OFF=""
fi

ok()   { printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
err()  { printf '%s✗%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; }

detect_desktop() {
  local raw="${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}"
  raw="${raw,,}"
  case "$raw" in
    *cinnamon*)          echo cinnamon ;;
    *gnome*|*unity*)     echo gnome ;;
    *xfce*)              echo xfce ;;
    *kde*|*plasma*)      echo kde ;;
    *mate*)              echo mate ;;
    *lxqt*|*lxde*)       echo lxqt ;;
    *)                   echo unknown ;;
  esac
}

is_wayland() {
  [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || [ -n "${WAYLAND_DISPLAY:-}" ]
}

# Convierte "Ctrl+Alt+D", "<Control><Alt>d" o "control+alt+d" a <Control><Alt>d
to_x11_combo() {
  local raw="${1,,}" part out=""
  raw="${raw//</}"; raw="${raw//>/}"
  IFS='+' read -ra parts <<< "$raw"
  for part in "${parts[@]}"; do
    part="${part// /}"
    case "$part" in
      ctrl|control) out+="<Control>" ;;
      alt)          out+="<Alt>" ;;
      shift)        out+="<Shift>" ;;
      super|meta|win|cmd) out+="<Super>" ;;
      "")           ;;
      *)            out+="$part" ;;
    esac
  done
  printf '%s' "$out"
}

# Convierte <Control><Alt>d a Ctrl+Alt+D (formato de KDE)
to_kde_combo() {
  local raw="$1" out=""
  raw="${raw//<Control>/Ctrl+}"
  raw="${raw//<Alt>/Alt+}"
  raw="${raw//<Shift>/Shift+}"
  raw="${raw//<Super>/Meta+}"
  raw="${raw//<//}"; raw="${raw//>//}"
  raw="${raw#/}"; raw="${raw%/}"
  out="$raw"
  # última letra en mayúscula
  printf '%s' "${out%?}$(printf '%s' "${out: -1}" | tr '[:lower:]' '[:upper:]')"
}

# --------------------------------------------------------------------------
# gsettings (Cinnamon / GNOME)
# --------------------------------------------------------------------------

parse_gsettings_list() {
  local raw="$1"
  raw="${raw#@as }"
  raw="${raw#[}"; raw="${raw%]}"
  raw="${raw//\'/}"
  local item
  local IFS=','
  for item in $raw; do
    item="${item// /}"
    [ -n "$item" ] && printf '%s\n' "$item"
  done
}

gsettings_array() {
  local out="[" first=1 item
  for item in "$@"; do
    [ -z "$item" ] && continue
    if [ "$first" -eq 1 ]; then first=0; else out+=", "; fi
    out+="'$item'"
  done
  out+="]"
  printf '%s' "$out"
}

gsettings_set_combo() {
  local schema="$1" list_schema="$2" list_key="$3" base_path="$4" combo="$5"
  local current items=() item target="" cmd

  if ! current="$(gsettings get "$list_schema" "$list_key" 2>/dev/null)"; then
    err "no se pudo leer la lista de atajos ($list_schema $list_key)"
    return 1
  fi
  while IFS= read -r item; do
    [ -n "$item" ] && items+=("$item")
  done < <(parse_gsettings_list "$current")

  for item in "${items[@]}"; do
    cmd="$(gsettings get "${schema}:${base_path}${item}/" command 2>/dev/null || true)"
    case "$cmd" in
      *dictado*) target="$item" ;;
    esac
  done

  if [ -z "$target" ]; then
    local i found
    for i in {0..50}; do
      found=0
      for item in "${items[@]}"; do
        [ "$item" = "custom$i" ] && found=1
      done
      if [ "$found" -eq 0 ]; then target="custom$i"; break; fi
    done
    items+=("$target")
  fi

  gsettings set "${schema}:${base_path}${target}/" name "Dictado" 2>/dev/null || true
  gsettings set "${schema}:${base_path}${target}/" command "$DICTADO_BIN toggle"
  gsettings set "${schema}:${base_path}${target}/" binding "['$combo']"
  gsettings set "$list_schema" "$list_key" "$(gsettings_array "${items[@]}")"
  ok "atajo $combo registrado en $target ($DICTADO_BIN toggle)"
}

gsettings_status() {
  local schema="$1" list_schema="$2" list_key="$3" base_path="$4"
  local current items=() item cmd binding found=0
  if ! current="$(gsettings get "$list_schema" "$list_key" 2>/dev/null)"; then
    err "no se pudo leer la lista de atajos ($list_schema $list_key)"
    return 1
  fi
  while IFS= read -r item; do
    [ -n "$item" ] && items+=("$item")
  done < <(parse_gsettings_list "$current")
  for item in "${items[@]}"; do
    cmd="$(gsettings get "${schema}:${base_path}${item}/" command 2>/dev/null || true)"
    case "$cmd" in
      *"$DICTADO_BIN"*)
        binding="$(gsettings get "${schema}:${base_path}${item}/" binding 2>/dev/null || true)"
        ok "$item → $binding → $(printf '%s' "$cmd" | tr -d "'")"
        found=1
        ;;
    esac
  done
  [ "$found" -eq 1 ] || err "no hay atajo de dictado para $DICTADO_BIN"
  return $((1 - found))
}

gsettings_remove() {
  local schema="$1" list_schema="$2" list_key="$3" base_path="$4"
  local current items=() keep=() item cmd found=0
  if ! current="$(gsettings get "$list_schema" "$list_key" 2>/dev/null)"; then
    err "no se pudo leer la lista de atajos ($list_schema $list_key)"
    return 1
  fi
  while IFS= read -r item; do
    [ -n "$item" ] && items+=("$item")
  done < <(parse_gsettings_list "$current")
  for item in "${items[@]}"; do
    cmd="$(gsettings get "${schema}:${base_path}${item}/" command 2>/dev/null || true)"
    case "$cmd" in
      *"$DICTADO_BIN"*)
        gsettings reset "${schema}:${base_path}${item}/" name 2>/dev/null || true
        gsettings reset "${schema}:${base_path}${item}/" command 2>/dev/null || true
        gsettings reset "${schema}:${base_path}${item}/" binding 2>/dev/null || true
        ok "eliminado $item"
        found=1
        ;;
      *) keep+=("$item") ;;
    esac
  done
  # Si no había nada que quitar, no reescribas la lista: evita perder atajos
  # si la lectura fue incompleta.
  if [ "$found" -eq 1 ]; then
    gsettings set "$list_schema" "$list_key" "$(gsettings_array "${keep[@]:-}")"
  fi
  return $((1 - found))
}

# --------------------------------------------------------------------------
# XFCE
# --------------------------------------------------------------------------

xfce_set_combo() {
  local combo="$1"
  if ! command -v xfconf-query >/dev/null 2>&1; then
    err "xfconf-query no está instalado"
    return 1
  fi
  xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/$combo" -n -t string -s "$DICTADO_BIN toggle" >/dev/null
  ok "atajo $combo registrado en XFCE"
}

xfce_status() {
  local found=0 line
  if ! command -v xfconf-query >/dev/null 2>&1; then
    err "xfconf-query no está instalado"
    return 1
  fi
  while IFS= read -r line; do
    case "$line" in
      *dictado*) ok "$line"; found=1 ;;
    esac
  done < <(xfconf-query -c xfce4-keyboard-shortcuts -l -v 2>/dev/null || true)
  return $((1 - found))
}

xfce_remove() {
  local line found=0
  while IFS= read -r line; do
    case "$line" in
      *"$DICTADO_BIN"*)
        xfconf-query -c xfce4-keyboard-shortcuts -p "${line%% *}" -r 2>/dev/null || true
        ok "eliminado ${line%% *}"
        found=1
        ;;
    esac
  done < <(xfconf-query -c xfce4-keyboard-shortcuts -l -v 2>/dev/null || true)
  return $((1 - found))
}

# --------------------------------------------------------------------------
# KDE Plasma (mejor esfuerzo)
# --------------------------------------------------------------------------

kde_desktop_file() {
  printf '%s' "$HOME/.local/share/applications/dictado.desktop"
}

kde_write_desktop() {
  local file
  file="$(kde_desktop_file)"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<EOF
[Desktop Entry]
Type=Application
Name=Dictado
Comment=Dictado por voz con limpieza
Exec=$DICTADO_BIN toggle
Icon=audio-input-microphone
Terminal=false
NoDisplay=true
EOF
  ok "creado $file"
}

kde_set_combo() {
  local combo="$1" tool=""
  kde_write_desktop
  if command -v kwriteconfig6 >/dev/null 2>&1; then tool="kwriteconfig6"
  elif command -v kwriteconfig5 >/dev/null 2>&1; then tool="kwriteconfig5"
  else
    warn "no se encontró kwriteconfig; asigna el atajo manualmente en Preferencias → Atajos"
    return 0
  fi
  "$tool" --file kglobalshortcutsrc --group services --group dictado.desktop \
    --key _launch "$combo,none,Dictado"
  ok "atajo $combo escrito en kglobalshortcutsrc"
  warn "si no se aplica, cierra sesión o revisa Preferencias → Atajos → Dictado"
}

kde_status() {
  local file tool=""
  file="$(kde_desktop_file)"
  [ -f "$file" ] || { err "no existe $file"; return 1; }
  if command -v kwriteconfig6 >/dev/null 2>&1; then tool="kwriteconfig6"
  elif command -v kwriteconfig5 >/dev/null 2>&1; then tool="kwriteconfig5"; fi
  if [ -n "$tool" ]; then
    local value
    value="$("$tool" --file kglobalshortcutsrc --group services --group dictado.desktop --key _launch --print 2>/dev/null || true)"
    ok "dictado.desktop → ${value:-sin atajo asignado}"
  else
    ok "dictado.desktop existe"
  fi
}

kde_remove() {
  local file tool=""
  file="$(kde_desktop_file)"
  rm -f "$file"
  if command -v kwriteconfig6 >/dev/null 2>&1; then tool="kwriteconfig6"
  elif command -v kwriteconfig5 >/dev/null 2>&1; then tool="kwriteconfig5"; fi
  if [ -n "$tool" ]; then
    "$tool" --file kglobalshortcutsrc --group services --group dictado.desktop --key _launch --delete 2>/dev/null || true
  fi
  ok "atajo de KDE eliminado"
}

# --------------------------------------------------------------------------
# xbindkeys (cualquier X11)
# --------------------------------------------------------------------------

XBINDRC="$HOME/.xbindkeysrc"

xbindkeys_set_combo() {
  local combo="$1" xcombo
  xcombo="$(to_x11_combo "$combo")"
  xcombo="${xcombo//<Control>/Control+}"
  xcombo="${xcombo//<Alt>/Alt+}"
  xcombo="${xcombo//<Shift>/Shift+}"
  xcombo="${xcombo//<Super>/Mod4+}"
  xcombo="${xcombo//<//}"; xcombo="${xcombo//>//}"
  xcombo="${xcombo%/}"

  if ! command -v xbindkeys >/dev/null 2>&1; then
    warn "xbindkeys no está instalado"
    echo "  Instálalo con el gestor de paquetes de tu distro y vuelve a ejecutar:"
    echo "    sudo apt install xbindkeys    # Debian/Ubuntu/Mint"
    echo "    sudo dnf install xbindkeys    # Fedora"
    echo "    sudo pacman -S xbindkeys      # Arch"
    return 1
  fi

  touch "$XBINDRC"
  # eliminar bloque previo
  python3 - "$XBINDRC" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = re.sub(r"\n?# dictado: inicio.*?# dictado: fin\n?", "\n", text, flags=re.S)
open(path, "w", encoding="utf-8").write(text)
PY
  cat >> "$XBINDRC" <<EOF
# dictado: inicio
"$DICTADO_BIN toggle"
  $xcombo
# dictado: fin
EOF
  pkill -x xbindkeys 2>/dev/null || true
  nohup xbindkeys >/dev/null 2>&1 &
  ok "atajo $xcombo registrado con xbindkeys"

  local autostart="$HOME/.config/autostart/xbindkeys.desktop"
  mkdir -p "$(dirname "$autostart")"
  cat > "$autostart" <<EOF
[Desktop Entry]
Type=Application
Name=xbindkeys
Comment=Atajos globales (dictado)
Exec=xbindkeys
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
  ok "autostart creado en $autostart"
}

xbindkeys_status() {
  if [ -f "$XBINDRC" ] && grep -q "dictado: inicio" "$XBINDRC"; then
    ok "$XBINDRC contiene el atajo de dictado"
    return 0
  fi
  err "no hay atajo de dictado en $XBINDRC"
  return 1
}

xbindkeys_remove() {
  if [ -f "$XBINDRC" ]; then
    python3 - "$XBINDRC" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = re.sub(r"\n?# dictado: inicio.*?# dictado: fin\n?", "\n", text, flags=re.S)
open(path, "w", encoding="utf-8").write(text)
PY
    pkill -x xbindkeys 2>/dev/null || true
    ok "atajo eliminado de $XBINDRC"
  fi
  rm -f "$HOME/.config/autostart/xbindkeys.desktop"
}

# --------------------------------------------------------------------------
# Instrucciones manuales
# --------------------------------------------------------------------------

manual_help() {
  cat <<EOF
No pude configurar el atajo automáticamente en este escritorio.

Crea un atajo personalizado que ejecute:

    $DICTADO_BIN toggle

Rutas habituales:
  • Cinnamon: Preferencias → Teclado → Atajos → Atajos personalizados
  • GNOME:    Configuración → Teclado → Atajos personalizados
  • XFCE:     Configuración → Teclado → Atajos de teclado
  • KDE:      Preferencias → Atajos → Atajos personalizados
  • MATE:     Preferencias → Teclado → Atajos

También puedes usar xbindkeys en cualquier X11:

    $DICTADO_BIN toggle
    Control+Alt+d
EOF
}

# --------------------------------------------------------------------------
# Acciones
# --------------------------------------------------------------------------

action="${1:-status}"
raw_combo="${2:-$DEFAULT_COMBO}"
combo="$(to_x11_combo "$raw_combo")"
desktop="$(detect_desktop)"

case "$action" in
  set)
    if is_wayland; then
      warn "sesión Wayland: el atajo se configura, pero el texto solo se copiará al portapapeles"
    fi
    case "$desktop" in
      cinnamon)
        gsettings_set_combo \
          "org.cinnamon.desktop.keybindings.custom-keybinding" \
          "org.cinnamon.desktop.keybindings" "custom-list" \
          "/org/cinnamon/desktop/keybindings/custom-keybindings/" \
          "$combo"
        ;;
      gnome)
        gsettings_set_combo \
          "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding" \
          "org.gnome.settings-daemon.plugins.media-keys" "custom-keybindings" \
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/" \
          "$combo"
        ;;
      xfce)
        xfce_set_combo "$combo"
        ;;
      kde)
        kde_set_combo "$(to_kde_combo "$combo")"
        ;;
      mate|lxqt|unknown)
        warn "escritorio no soportado directamente: $desktop"
        if [ "$(is_wayland && echo yes || echo no)" = "no" ]; then
          xbindkeys_set_combo "$combo" || manual_help
        else
          manual_help
        fi
        ;;
    esac
    ;;
  status)
    case "$desktop" in
      cinnamon)
        gsettings_status \
          "org.cinnamon.desktop.keybindings.custom-keybinding" \
          "org.cinnamon.desktop.keybindings" "custom-list" \
          "/org/cinnamon/desktop/keybindings/custom-keybindings/"
        ;;
      gnome)
        gsettings_status \
          "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding" \
          "org.gnome.settings-daemon.plugins.media-keys" "custom-keybindings" \
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
        ;;
      xfce) xfce_status ;;
      kde)  kde_status ;;
      *)    xbindkeys_status ;;
    esac
    ;;
  remove)
    case "$desktop" in
      cinnamon)
        gsettings_remove \
          "org.cinnamon.desktop.keybindings.custom-keybinding" \
          "org.cinnamon.desktop.keybindings" "custom-list" \
          "/org/cinnamon/desktop/keybindings/custom-keybindings/"
        ;;
      gnome)
        gsettings_remove \
          "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding" \
          "org.gnome.settings-daemon.plugins.media-keys" "custom-keybindings" \
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
        ;;
      xfce) xfce_remove ;;
      kde)  kde_remove ;;
      *)    xbindkeys_remove ;;
    esac
    ;;
  *)
    err "acción desconocida: $action (usa set, status o remove)"
    exit 2
    ;;
esac
