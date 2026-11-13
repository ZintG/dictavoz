# dictado

Dictado por voz global para Linux con limpieza automática del texto.

Pulsas un atajo, hablas, vuelves a pulsar y el texto aparece limpio en la
ventana donde estabas: sin muletillas, con puntuación, mayúsculas y los
términos técnicos respetados. Funciona en cualquier escritorio Linux; el
pegado automático está disponible en X11 y en Wayland el texto queda en el
portapapeles.

```
atajo global → arecord → recorte de silencio → Gemini → reglas locales → pegado
```

## Índice

- [Qué hace](#qué-hace)
- [Requisitos](#requisitos)
- [Instalación rápida](#instalación-rápida)
- [La clave de API](#la-clave-de-api)
- [Uso diario](#uso-diario)
- [Configuración](#configuración)
- [X11 y Wayland](#x11-y-wayland)
- [Privacidad](#privacidad)
- [Solución de problemas](#solución-de-problemas)
- [Documentación](#documentación)
- [Desinstalar](#desinstalar)
- [Licencia](#licencia)

## Qué hace

1. **Graba** con `arecord` a 16 kHz mono mientras dictas.
2. **Recorta** el silencio del principio y del final con `ffmpeg`.
3. **Transcribe** con el modelo `gemini-3.5-transcribe` en modo `smart`, con
   tu idioma y un vocabulario propio de términos técnicos.
4. **Limpia** con reglas locales: muletillas, repeticiones, falsos comienzos,
   puntuación, mayúsculas y espacios.
5. **Pule** los textos largos con `gemini-3.5-flash-lite`, con validación
   estricta: si la respuesta pierde términos técnicos o cambia demasiado la
   longitud, se descarta y se usa la limpieza por reglas.
6. **Copia** al portapapeles y **pega** en la ventana que estaba activa al
   empezar, sin robar el foco.

La limpieza por reglas es determinista y funciona sin conexión. Solo la
transcripción y el pulido opcional llaman a la API.

## Requisitos

- Linux con X11 o Wayland.
- Python 3.9 o superior (`python3-tomli` en versiones anteriores a 3.11).
- `arecord` (alsa-utils), `notify-send` (libnotify).
- `ffmpeg` y `ffprobe` para recortar el silencio (recomendado).
- En X11: `xclip` y `xdotool`.
- En Wayland: `wl-clipboard`.
- Una clave gratuita de Google AI Studio.

El instalador detecta la distribución e instala lo que falte con `apt`, `dnf`,
`pacman`, `zypper` o `apk`.

## Instalación rápida

```bash
git clone https://github.com/ZintG/dictado.git
cd dictado
./install.sh
```

El instalador hace siete pasos y te va contando lo que ocurre:

1. Comprueba el sistema, Python y la sesión gráfica.
2. Instala las dependencias que falten (te pide permiso con `sudo`).
3. Copia el programa en `~/.local/bin` y el gestor de atajos en
   `~/.local/lib/dictado`.
4. Te guía para crear y pegar la clave de Gemini.
5. Crea `~/.config/dictado/config.toml` si no existe.
6. Te pregunta la combinación del atajo (por defecto `Ctrl+Alt+D`) y la
   registra.
7. Configura la integración con opencode y ejecuta el diagnóstico.

Al terminar, pulsa `Ctrl+Alt+D` y habla.

### Opciones del instalador

```text
--prefix DIR         instala en otro prefijo (por defecto ~/.local)
--hotkey COMBO       cambia el atajo (por defecto Ctrl+Alt+D)
--non-interactive    sin preguntas; usa la variable GEMINI_API_KEY
--dry-run            muestra lo que haría sin tocar nada
--no-deps            no instala paquetes del sistema
--no-hotkey          no configura el atajo global
--no-opencode        no modifica la configuración de opencode
--uninstall          desinstala y conserva tus datos
--purge              con --uninstall, borra también configuración e historial
```

Ejemplos:

```bash
# Otro atajo y otro prefijo
./install.sh --hotkey "Ctrl+Shift+Space" --prefix "$HOME/.local"

# Instalación desatendida con la clave en el entorno
GEMINI_API_KEY="tu-clave" ./install.sh --non-interactive

# Ver el plan sin ejecutarlo
./install.sh --dry-run
```

Si `~/.local/bin` no está en tu `PATH`, el instalador te muestra la línea que
debes añadir a tu `~/.profile` o `~/.bashrc`.

## La clave de API

El proyecto usa la API de Gemini. La clave es gratuita para uso personal y se
crea en [Google AI Studio](https://aistudio.google.com/apikey):

1. Abre el enlace e inicia sesión con tu cuenta de Google.
2. Pulsa **Create API key**.
3. Copia el valor, que empieza por `AIza`.

El instalador la pide sin mostrarla y la guarda en `~/.config/dictado/env`
con permisos `600`. Nunca se escribe en el repositorio ni se envía a otro
sitio que no sea la API de Gemini.

Puedes cambiarla más tarde:

```bash
dictado config set-key
```

También puedes definir `GEMINI_API_KEY` en tu entorno; el programa usa primero
el archivo de configuración y después la variable.

## Uso diario

```bash
dictado toggle            # empezar o parar (lo que hace el atajo)
dictado start             # empezar a grabar
dictado stop              # parar, transcribir, limpiar y pegar
dictado status            # ¿está grabando?
dictado doctor            # diagnóstico completo del entorno
dictado history           # últimos dictados
dictado purge             # borrar historial y audio pendiente
```

Herramientas para ajustar el resultado sin hablar:

```bash
dictado clean --text "eh, o sea, abre el archivo, ¿sabes?"
dictado clean --file nota.txt
dictado transcribe prueba.wav
```

`dictado doctor` comprueba binarios, micrófono, grabación real, portapapeles,
ventana activa, clave, permisos, notificaciones, atajo y la integración con
opencode. Es el primer sitio donde mirar si algo falla.

## Configuración

El archivo es `~/.config/dictado/config.toml`. Se aplica en el siguiente
dictado, sin reiniciar nada. Hay un ejemplo comentado en
[`config/config.example.toml`](config/config.example.toml).

```bash
dictado config show       # ver la configuración activa
dictado config edit       # abrirla con tu editor
dictado config path       # rutas de configuración y datos
```

Ajustes que suele merecer la pena tocar:

- `stt.language`: tu variante de español o el idioma que dictes.
- `stt.custom_vocabulary`: nombres propios, siglas y jerga de tu trabajo.
- `audio.device`: otro micrófono (míralo con `arecord -l`).
- `cleanup.llm`: desactiva el pulido si prefieres solo reglas.
- `insert.key`: `ctrl+v`, `ctrl+shift+v` o `type` si la autodetección falla.
- `history.enabled`: desactívalo si no quieres guardar el texto dictado.

### El atajo global

```bash
dictado hotkey status
dictado hotkey set "Ctrl+Alt+D"
dictado hotkey set "Ctrl+Shift+Space"
dictado hotkey remove
```

El gestor de atajos usa la interfaz nativa de cada escritorio:

| Escritorio | Mecanismo |
| --- | --- |
| Cinnamon | `gsettings` (`custom-list`) |
| GNOME | `gsettings` (`custom-keybindings`) |
| XFCE | `xfconf-query` |
| KDE Plasma | archivo `.desktop` + `kglobalshortcutsrc` (mejor esfuerzo) |
| MATE, LXQt, otros X11 | `xbindkeys` como alternativa |

Siempre conserva los atajos que ya tuvieras: añade el de dictado a la lista,
nunca la reemplaza.

## X11 y Wayland

- **X11**: soporte completo. El programa recuerda la ventana activa, pega con
  `xdotool` y distingue terminales (`ctrl+shift+v`) del resto (`ctrl+v`).
- **Wayland**: el atajo y la transcripción funcionan, pero el texto solo se
  copia al portapapeles. Los compositores no permiten inyectar pulsaciones en
  otras ventanas sin permisos especiales. Pégalo con `Ctrl+V`.

## Privacidad

- El audio se envía a la API de Gemini para transcribirlo. No se guarda en
  ningún servidor propio.
- El texto dictado se guarda en `~/.local/state/dictado/history.jsonl` con
  permisos `600`. Puedes desactivarlo o borrarlo cuando quieras.
- Los audios que fallan se conservan unos días en
  `~/.local/state/dictado/pending` para reintentar; se limpian solos.
- La clave vive en `~/.config/dictado/env` con permisos `600`.
- El plan gratuito de Gemini puede usar el contenido para mejorar sus
  productos. Si eso no te vale, revisa las condiciones de Google antes de
  dictar información sensible.

Más detalle en [`docs/privacidad.md`](docs/privacidad.md).

## Solución de problemas

| Síntoma | Causa habitual | Solución |
| --- | --- | --- |
| No aparece la notificación «Transcribiendo» | Notificaciones desactivadas en Cinnamon | `gsettings set org.cinnamon.desktop.notifications display-notifications true` |
| El texto se copia pero no se pega | La ventana cambió de foco o es Wayland | Vuelve a la ventana y pega con `Ctrl+V` |
| «no se pudo escribir en el portapapeles» | Falta `xclip` o `wl-clipboard` | Instálalo con tu gestor de paquetes |
| El atajo no hace nada | Otro programa lo usa o no se registró | `dictado hotkey status` y `dictado doctor` |
| Error 400 o 403 de la API | Clave mal copiada o sin permisos | `dictado config set-key` |
| El texto sale con muletillas | El pulido con LLM está desactivado | Revisa `cleanup.rules` y `cleanup.llm` |
| La grabación está vacía | Micrófono equivocado | Cambia `audio.device` (`arecord -l`) |

Guía completa en [`docs/solucion-problemas.md`](docs/solucion-problemas.md).

## Documentación

- [`docs/instalacion.md`](docs/instalacion.md): instalación paso a paso por
  distribución y escritorio.
- [`docs/configuracion.md`](docs/configuracion.md): todas las opciones.
- [`docs/atajos.md`](docs/atajos.md): cómo funciona el atajo global.
- [`docs/arquitectura.md`](docs/arquitectura.md): cómo encajan las piezas.
- [`docs/privacidad.md`](docs/privacidad.md): qué datos salen y cuáles se
  quedan.
- [`docs/solucion-problemas.md`](docs/solucion-problemas.md): diagnóstico.
- [`README.en.md`](README.en.md): English summary.

## Desarrollo

```bash
make test           # pruebas unitarias
make lint           # sintaxis de Python y Bash
make check-secrets  # busca claves y datos personales
```

No hace falta red ni micrófono para las pruebas: cubren la limpieza por reglas
y la validación del pulido.

## Desinstalar

```bash
./uninstall.sh            # quita el programa y el atajo, conserva tus datos
./uninstall.sh --purge    # borra también configuración e historial
```

## Licencia

MIT. Consulta [`LICENSE`](LICENSE).
