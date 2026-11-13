# Privacidad y seguridad

dictado es una herramienta local, pero no funciona sin red: la transcripción
depende de la API de Gemini. Esta página explica exactamente qué sale del
equipo, qué se guarda y cómo borrarlo.

## Qué se envía a internet

Solo se hacen peticiones al host configurado en `stt.api_base`, que por
defecto es:

```text
https://generativelanguage.googleapis.com
```

Si cambias `api_base` por un proxy, la clave y el contenido también se envían
a ese host.

| Momento | Qué se envía | Qué se recibe |
| --- | --- | --- |
| Transcripción | Audio WAV en base64, idioma, modo y vocabulario | Texto transcrito |
| Pulido (textos largos) | Texto ya limpio y las instrucciones del sistema | Texto pulido |
| Diagnóstico (`doctor`) | Una petición mínima de texto y una consulta de metadatos del modelo | Respuesta corta y metadatos |

Las peticiones de transcripción y pulido envían `store: false`. Sin esa opción,
la API de Interactions conserva las interacciones durante un día en el tier
gratuito. No hay telemetría, analítica, publicidad ni servidores propios. El
programa no envía el historial, la configuración ni la clave a ningún otro
sitio distinto del host configurado.

### El plan gratuito

La capa gratuita de Gemini puede usar el contenido enviado para mejorar los
productos de Google. Si dictas información confidencial, revisa las
[condiciones de la API de Gemini](https://ai.google.dev/gemini-api/terms) y
valora un plan de pago con condiciones distintas.

No dictes contraseñas, claves privadas, datos de salud ni información de
terceros que no quieras compartir con el proveedor del modelo.

## Qué se guarda en el equipo

| Archivo | Contenido | Permisos |
| --- | --- | --- |
| `~/.config/dictado/env` | Clave de API de Gemini | `600` |
| `~/.config/dictado/config.toml` | Configuración | `600` |
| `~/.local/state/dictado/history.jsonl` | Texto dictado y metadatos | `600` |
| `~/.local/state/dictado/pending/` | Audios que fallaron | `700` |
| `$XDG_RUNTIME_DIR/dictado/state.json` | Estado de la grabación | `600` |

El directorio de configuración se crea con permisos `700`. Los archivos
sensibles se fuerzan a `600` cada vez que se escriben.

### La clave de API

Se guarda en texto plano en `~/.config/dictado/env`, protegida solo por los
permisos del sistema de archivos. No se cifra porque el programa necesita
leerla sin intervención del usuario. Si alguien tiene acceso a tu cuenta de
Linux, puede leerla.

Recomendaciones:

- No compartas el archivo ni lo subas a ningún repositorio.
- Si crees que se ha filtrado, revoca la clave en Google AI Studio y crea otra.
- Usa una clave distinta para cada herramienta.
- No la pases por argumentos de línea de comandos: quedaría en el historial del
  shell. Usa `dictado config set-key` o la variable `GEMINI_API_KEY`.

`scripts/check-secrets.sh` revisa el repositorio en busca de claves, correos y
rutas personales. La integración continua lo ejecuta en cada cambio.

### El historial

`history.jsonl` contiene el texto dictado. Es útil para depurar y para
recuperar algo que pegaste mal, pero es información sensible.

Para desactivarlo:

```toml
[history]
enabled = false
```

Para borrarlo:

```bash
dictado purge
```

### Los audios pendientes

Si la transcripción falla, el WAV se copia a `pending/` para que puedas
reintentarlo con:

```bash
dictado transcribe ~/.local/state/dictado/pending/rec-....wav
```

Se borran automáticamente después de `history.pending_days` días (7 por
defecto). Para vaciarlos antes:

```bash
dictado purge
```

### El portapapeles

Durante el pegado, el texto dictado pasa por el portapapeles del sistema. Si
`insert.restore_clipboard` está activo, se restaura el contenido anterior
después de pegar. Ese contenido anterior se guarda brevemente en
`$XDG_RUNTIME_DIR/dictado/clipboard-<pid>.txt`, con permisos `600`, y se borra
al restaurarlo.

Si copiaste algo sensible antes de dictar, ese contenido también pasa por ese
archivo temporal durante unos instantes.

### Las notificaciones

Las notificaciones muestran el número de caracteres insertados, no el texto.
Los mensajes de error pueden incluir el nombre del archivo de audio guardado,
pero no su contenido.

## Permisos del micrófono

dictado usa `arecord`, que accede al dispositivo de ALSA del usuario. No
necesita privilegios de root ni grupos especiales en la mayoría de las
distribuciones. Si tu sistema usa PipeWire o PulseAudio, `arecord` sigue
funcionando a través de la capa de compatibilidad.

No hay grabación en segundo plano: `arecord` solo se ejecuta entre las dos
pulsaciones del atajo. `dictado status` muestra si hay una grabación activa.

## Superficie de confianza

- El programa no descarga código ni actualiza nada por su cuenta.
- No ejecuta contenido que venga de la API: solo inserta texto.
- La respuesta del modelo pasa por `valid_polish` antes de usarse.
- Los textos se insertan con el portapapeles y un atajo de pegado, no con
  `eval` ni con comandos del shell.
- Las rutas de configuración y datos se derivan de `HOME` y de las variables
  XDG, no de entradas de la API.

## Buenas prácticas

1. Revisa `git diff` antes de publicar un fork.
2. Ejecuta `make check-secrets`.
3. No incluyas tu `~/.config/dictado/` en copias de seguridad compartidas.
4. Desactiva el historial si dictas información sensible.
5. Revoca la clave si sospechas que se ha filtrado.
6. Mantén el sistema y `ffmpeg` actualizados.

## Borrar todo

```bash
./uninstall.sh --purge
```

Elimina el ejecutable, el atajo, la configuración, la clave, el historial y los
audios pendientes. No puede borrar lo que ya se haya enviado a la API de
Gemini: para eso, consulta los controles de tu cuenta de Google.
