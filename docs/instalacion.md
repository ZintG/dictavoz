# Instalación

Esta guía cubre la instalación completa en cualquier distribución Linux y las
particularidades de cada escritorio.

## Antes de empezar

Necesitas:

- Una sesión gráfica Linux (X11 o Wayland).
- `python3` 3.9 o superior.
- Una cuenta de Google para crear la clave de Gemini.
- Permiso para instalar paquetes con `sudo` (solo durante la instalación).

Comprueba tu versión de Python:

```bash
python3 --version
```

## Instalación recomendada

```bash
git clone https://github.com/ZintG/dictavoz.git
cd dictavoz
./install.sh
```

El instalador es interactivo y explica cada paso. Si prefieres revisar antes
lo que va a hacer:

```bash
./install.sh --dry-run
```

### Los siete pasos

1. **Sistema**: comprueba Python, la sesión gráfica, el escritorio y el gestor
   de paquetes.
2. **Dependencias**: instala lo que falte con el gestor de tu distribución.
3. **Archivos**: copia `bin/dictado` en `~/.local/bin/dictado` y
   `scripts/hotkey.sh` en `~/.local/lib/dictado/hotkey.sh`.
4. **Clave**: te guía para crear la clave en Google AI Studio y la guarda en
   `~/.config/dictado/env` con permisos `600`.
5. **Configuración**: crea `~/.config/dictado/config.toml` desde el ejemplo,
   sin sobrescribir una configuración existente.
6. **Atajo**: te propone `Ctrl+Alt+D`, te permite cambiarlo y lo registra con
   la interfaz nativa del escritorio.
7. **Integración**: configura `prompt.paste = "full"` en opencode si lo
   detecta y ejecuta `dictado doctor`.

## Dependencias por distribución

El instalador las resuelve solo, pero estas son las equivalencias por si
prefieres instalarlas a mano.

| Necesidad | Debian, Ubuntu, Mint | Fedora | Arch | openSUSE | Alpine |
| --- | --- | --- | --- | --- | --- |
| Grabar audio | `alsa-utils` | `alsa-utils` | `alsa-utils` | `alsa-utils` | `alsa-utils` |
| Recortar silencio | `ffmpeg` | `ffmpeg` | `ffmpeg` | `ffmpeg` | `ffmpeg` |
| Portapapeles X11 | `xclip` | `xclip` | `xclip` | `xclip` | `xclip` |
| Pegar en X11 | `xdotool` | `xdotool` | `xdotool` | `xdotool` | `xdotool` |
| Notificaciones | `libnotify-bin` | `libnotify` | `libnotify` | `libnotify-tools` | `libnotify` |
| Portapapeles Wayland | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` |
| Python 3.9/3.10 | `python3-tomli` | — | — | — | `py3-tomli` |

> En Fedora, `ffmpeg` se distribuye a través de RPM Fusion. Si el instalador no
> lo encuentra, habilita ese repositorio o instala solo lo demás: el programa
> funciona sin `ffmpeg`, únicamente no recorta el silencio.

Ejemplos:

```bash
# Debian, Ubuntu, Linux Mint, Pop!_OS, elementary
sudo apt update
sudo apt install alsa-utils ffmpeg xclip xdotool libnotify-bin

# Fedora
sudo dnf install alsa-utils ffmpeg xclip xdotool libnotify

# Arch, Manjaro, EndeavourOS
sudo pacman -S alsa-utils ffmpeg xclip xdotool libnotify

# openSUSE
sudo zypper install alsa-utils ffmpeg xclip xdotool libnotify-tools

# Alpine
sudo apk add alsa-utils ffmpeg xclip xdotool libnotify wl-clipboard
```

## Instalación no interactiva

Útil para scripts o para reinstalar sin responder preguntas:

```bash
GEMINI_API_KEY="tu-clave" ./install.sh --non-interactive
```

Sin la variable, el programa se instala igualmente y te avisa de que falta la
clave. Puedes añadirla después:

```bash
dictado config set-key
```

## Cambiar el prefijo

Por defecto se instala en `~/.local`. Para usar otro directorio:

```bash
./install.sh --prefix "$HOME/.local"
./install.sh --prefix /opt/dictado
```

Si eliges un prefijo del sistema como `/usr/local`, necesitarás permisos de
escritura. El instalador no usa `sudo` para copiar archivos: ejecútalo con un
prefijo que tu usuario pueda escribir, o prepara el directorio antes.

## `PATH`

Si `~/.local/bin` no está en tu `PATH`, añade esta línea al final de
`~/.profile` (o `~/.bashrc` si usas Bash de forma interactiva):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Después abre una terminal nueva o recarga el archivo:

```bash
source ~/.profile
```

Comprueba que el programa responde:

```bash
dictado --version
```

## El atajo global

El instalador lo configura automáticamente. Puedes cambiarlo en cualquier
momento:

```bash
dictado hotkey set "Ctrl+Shift+Space"
dictado hotkey status
```

Consulta [`atajos.md`](atajos.md) para los detalles por escritorio.

Si el registro automático falla, crea un atajo personalizado que ejecute:

```text
dictado toggle
```

Las rutas habituales están en la configuración de teclado de tu escritorio:

- **Cinnamon**: Preferencias → Teclado → Atajos → Atajos personalizados.
- **GNOME**: Configuración → Teclado → Atajos personalizados.
- **XFCE**: Configuración → Teclado → Atajos de teclado.
- **KDE Plasma**: Preferencias → Atajos → Atajos personalizados.
- **MATE**: Preferencias → Teclado → Atajos.

## Verificar la instalación

```bash
dictado doctor
```

El diagnóstico revisa:

- Sesión gráfica y escritorio.
- Binarios necesarios y opcionales.
- Tarjetas de sonido y una grabación real de un segundo.
- Escritura y lectura del portapapeles.
- Ventana activa (solo X11).
- Presencia de la clave y una llamada real a la API.
- Permisos de los archivos sensibles.
- Notificaciones del escritorio.
- Atajo registrado.
- Integración con opencode.

Si todo está en orden, la última línea indica `0 fallos`. Los avisos (`!`) no
impiden usar el programa, pero conviene revisarlos.

Prueba final:

1. Abre un editor de texto y haz clic dentro.
2. Pulsa `Ctrl+Alt+D`.
3. Di una frase.
4. Vuelve a pulsar `Ctrl+Alt+D`.
5. En unos segundos deberías ver el texto limpio pegado.

## Instalación manual

Si no quieres ejecutar el instalador:

```bash
install -Dm755 bin/dictado ~/.local/bin/dictado
install -Dm755 scripts/hotkey.sh ~/.local/lib/dictado/hotkey.sh
mkdir -p ~/.config/dictado
cp config/config.example.toml ~/.config/dictado/config.toml
chmod 700 ~/.config/dictado
chmod 600 ~/.config/dictado/config.toml
~/.local/bin/dictado config set-key
~/.local/bin/dictado hotkey set "Ctrl+Alt+D"
```

## Actualizar

```bash
cd dictavoz
git pull
./install.sh
```

El instalador reemplaza el ejecutable y el gestor de atajos, pero **no**
sobrescribe `config.toml` ni la clave. Si quieres comparar tu configuración con
la nueva versión:

```bash
dictado config show
```

## Desinstalar

```bash
./uninstall.sh
```

Quita el ejecutable, el gestor de atajos y la entrada del atajo. Conserva la
configuración y el historial por si vuelves a instalarlo.

Para borrarlo todo:

```bash
./uninstall.sh --purge
```

También puedes hacerlo desde el propio programa:

```bash
dictado purge          # historial y audio
dictado purge --all    # además, la configuración
```
