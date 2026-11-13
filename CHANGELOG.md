# Historial de cambios

Todas las versiones notables se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[versionado semántico](https://semver.org/lang/es/).

## [1.0.2] - 2026-11-13

### Añadido

- Agentes de auditoría de solo lectura para revisar el repositorio y verificar
  los modelos de Gemini del tier gratuito.
- Comprobación del modelo de transcripción en `doctor` mediante metadatos, sin
  consumir cuota de generación.
- Pruebas para purga completa, portapapeles, configuración inválida, atajos KDE,
  respuestas no JSON, duración sin `ffprobe` y fallos de inserción.
- Python 3.13 y 3.14 en la matriz de CI.

### Corregido

- `dictado purge --all` borra ahora el historial además de la configuración y
  los audios, y el mensaje ya no afirma que el programa esté desinstalado.
- `doctor` guarda y restaura el portapapeles en lugar de destruirlo.
- Un `config.toml` inválido se muestra como error legible y ya no bloquea
  `config edit`, `purge`, `history` ni `hotkey`.
- Los atajos KDE con teclas con nombre (`Space`, `Return`, etc.) se convierten
  correctamente; los escritorios sin soporte ya no fingen éxito y `doctor`
  detecta un binding KDE vacío.
- Los audios que superan el límite inline se rechazan con un mensaje claro
  antes de enviarlos a la API.
- Si falla `write_state`, se termina `arecord` y se limpia el WAV parcial.
- Las peticiones usan `store: false` y la documentación explica la retención de
  la API y el efecto de `stt.api_base`.
- Las respuestas no JSON y los errores de red se convierten en `DictadoError`;
  los 429 respetan `Retry-After` y distinguen el límite diario.
- Los audios pendientes antiguos se limpian también cuando falla un dictado.
- Si falla el pegado, el texto se guarda en el historial y se avisa de que está
  en el portapapeles o de que solo está en el historial.
- El instalador normaliza los permisos `600` de `env` y `config.toml`
  existentes; `config edit` también los aplica.
- `EDITOR`/`VISUAL` admiten argumentos, una clave vacía ya no se acepta como
  válida y `--purge` exige `--uninstall`.
- La restauración del portapapeles respeta `paste_delay_ms`.
- `clean_rules` conserva los saltos de línea y `verbatim` se envía con el
  formato de objeto que espera la API.
- El pulido rechaza interacciones incompletas, usa `thinking_level: "minimal"`,
  limita la salida según el texto y exige un `ratio_min` de `0.70`.

### Cambiado

- `doctor` trata como aviso una integración de opencode no configurada.
- `.gitignore` ignora los archivos `*.patch`.

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
