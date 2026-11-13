# Historial de cambios

Todas las versiones notables se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[versionado semántico](https://semver.org/lang/es/).

## [1.0.1] - 2026-11-13

### Corregido

- `dictado` y `doctor` respetan `XDG_CONFIG_HOME` y `XDG_STATE_HOME`, igual que
  el instalador. Las rutas relativas se ignoran.
- El instalador ya no crea la configuración de opencode ni su directorio:
  solo modifica una configuración de opencode que ya exista.
- Al desinstalar se restaura el `prompt.paste` anterior de opencode si el
  instalador guardó una copia. Las instalaciones antiguas no tienen esa copia,
  así que conservan el valor actual y muestran un aviso.
- Si la configuración de opencode es inválida o `prompt` no es un objeto, se
  deja intacta en lugar de sobrescribirla.
- `insert.key = "type"` escribe el texto con `xdotool type` en lugar de
  enviarlo como si fuera una tecla.
- `api_post` captura `socket.timeout` también en Python 3.9, con el mismo
  reintento y el mismo mensaje de tiempo de espera agotado.
- La limpieza por reglas conserva las comas legítimas antes de `de`, `del`,
  `con` y `para`, no colapsa palabras con dígitos y mantiene `esto` al inicio
  de frase.
- El instalador incluye `xprop` y `doctor` lo comprueba en X11, avisando de
  que sin él no se distinguen las terminales.
- El aviso al empezar a grabar ya no depende del atajo configurado.
- Si falla la transcripción y el audio se copia a pendientes, se borran el wav
  original y su `.trim.wav`; si la copia falla, se conservan ambos.
- `dictado purge` rechaza borrar nada mientras hay una grabación activa,
  también con `--all`, y pide pararla primero con `dictado stop`.

## [1.0.0] - 2026-11-13

Primera versión pública.

### Añadido

- Dictado global con atajo configurable y pegado en la ventana activa.
- Grabación con `arecord` y recorte de silencio con `ffmpeg`.
- Transcripción con Gemini (`gemini-3.5-transcribe`) en modo `smart`, con
  idioma y vocabulario propio.
- Limpieza determinista de muletillas, repeticiones, falsos comienzos,
  puntuación y mayúsculas.
- Pulido opcional de textos largos con `gemini-3.5-flash-lite` y validación
  estricta de la respuesta.
- Portapapeles con `xclip` en X11 y `wl-copy` en Wayland.
- Pegado automático en X11, con detección de terminales.
- Historial local con rotación y borrado de audios pendientes.
- Diagnóstico `dictado doctor`.
- Instalador interactivo con detección de `apt`, `dnf`, `pacman`, `zypper` y
  `apk`, configuración guiada de la clave y modo desatendido.
- Gestor de atajos para Cinnamon, GNOME, XFCE, KDE y `xbindkeys`.
- Integración con opencode (`prompt.paste = "full"`).
- Documentación en español y resumen en inglés.
- Pruebas unitarias de la limpieza y de la validación del pulido.
- Integración continua con pruebas, ShellCheck y búsqueda de secretos.

### Limitaciones conocidas

- Wayland solo copia al portapapeles; no pega automáticamente.
- KDE Plasma requiere cerrar sesión o ajustar el atajo a mano en algunos casos.
- El plan gratuito de Gemini puede usar el contenido para mejorar sus
  productos.
