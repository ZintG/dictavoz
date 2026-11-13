# Configuración

Toda la configuración vive en:

```text
~/.config/dictado/config.toml
```

Los cambios se aplican en el siguiente dictado: no hay que reiniciar nada.

```bash
dictado config show    # ver el archivo activo
dictado config edit    # abrirlo con $VISUAL, $EDITOR o nano
dictado config path    # rutas de configuración, clave y datos
```

Si el archivo no existe, se usan los valores por defecto. El ejemplo completo
y comentado está en [`../config/config.example.toml`](../config/config.example.toml).

## Audio

```toml
[audio]
device = "default"
rate = 16000
channels = 1
min_duration = 0.4
silence_threshold = "-45dB"
silence_start_duration = 0.1
silence_stop_duration = 0.4
```

| Clave | Por defecto | Qué hace |
| --- | --- | --- |
| `device` | `"default"` | Dispositivo de ALSA. `arecord -l` lista los disponibles. |
| `rate` | `16000` | Frecuencia de muestreo en Hz. 16 kHz es suficiente para voz. |
| `channels` | `1` | Canales. Mono reduce el tamaño y funciona igual. |
| `min_duration` | `0.4` | Descarta grabaciones más cortas (segundos). |
| `silence_threshold` | `"-45dB"` | Umbral para considerar silencio. |
| `silence_start_duration` | `0.1` | Silencio inicial que se recorta (segundos). |
| `silence_stop_duration` | `0.4` | Silencio final que se recorta (segundos). |

El recorte requiere `ffmpeg`. Sin él, se envía la grabación completa.

## Reconocimiento (STT)

```toml
[stt]
backend = "gemini"
model = "gemini-3.5-transcribe"
language = "es-419"
mode = "smart"
api_base = "https://generativelanguage.googleapis.com/v1beta"
timeout = 90
custom_vocabulary = ["opencode", "TypeScript", "API"]
```

| Clave | Por defecto | Qué hace |
| --- | --- | --- |
| `backend` | `"gemini"` | Único backend en esta versión. |
| `model` | `"gemini-3.5-transcribe"` | Modelo de transcripción. |
| `language` | `"es-419"` | Idioma hablado en formato BCP-47. |
| `mode` | `"smart"` | `smart` corrige y puntúa; `verbatim` transcribe literalmente. |
| `api_base` | URL de Gemini | Solo cámbialo para proxies compatibles. |
| `timeout` | `90` | Segundos máximos de espera por petición. |
| `custom_vocabulary` | `[]` | Términos que el modelo debe respetar. |

### Elegir el idioma

- `es-419`: español latinoamericano neutro.
- `es-ES`: español de España.
- `en-US`, `en-GB`: inglés.
- `pt-BR`, `fr-FR`, `de-DE`, `it-IT`: otros idiomas habituales.

### Vocabulario propio

Incluye nombres propios, siglas, herramientas y jerga de tu trabajo. Ayuda
mucho con palabras que el modelo no conocería de otro modo.

```toml
custom_vocabulary = [
  "opencode", "TypeScript", "PostgreSQL", "kubectl",
  "pull request", "deploy", "endpoint", "Nintendo",
]
```

Recomendado: menos de cien entradas. Si la lista crece demasiado, el modelo
puede perder precisión.

## Limpieza

```toml
[cleanup]
rules = true
llm = true
llm_model = "gemini-3.5-flash-lite"
llm_min_chars = 280
llm_min_sentences = 3
llm_timeout = 45
ratio_min = 0.55
ratio_max = 1.35
```

| Clave | Por defecto | Qué hace |
| --- | --- | --- |
| `rules` | `true` | Limpieza determinista: muletillas, repeticiones, puntuación. |
| `llm` | `true` | Pulido opcional con un modelo de lenguaje. |
| `llm_model` | `"gemini-3.5-flash-lite"` | Modelo usado para pulir. |
| `llm_min_chars` | `280` | Longitud a partir de la cual se pule. |
| `llm_min_sentences` | `3` | Frases a partir de las cuales se pule. |
| `llm_timeout` | `45` | Segundos máximos para el pulido. |
| `ratio_min` | `0.55` | Longitud mínima aceptable respecto al original. |
| `ratio_max` | `1.35` | Longitud máxima aceptable respecto al original. |

El pulido se ejecuta si se supera **cualquiera** de los dos umbrales
(`llm_min_chars` o `llm_min_sentences`), o si quedan repeticiones evidentes.

Antes de aceptar la respuesta del modelo se comprueba que:

- No esté vacía.
- No empiece por fórmulas como «aquí tienes» o «claro».
- No contenga bloques de código.
- Su longitud esté dentro del rango configurado.
- Conserve todas las rutas, banderas, URLs, nombres de archivo, identificadores
  en `camelCase` o `snake_case` y extensiones técnicas.

Si falla alguna comprobación, se descarta el pulido y se usa el texto de las
reglas. Nunca se pierde el dictado por un pulido defectuoso.

### Desactivar el pulido

```toml
[cleanup]
llm = false
```

Ventajas: menos latencia, funciona sin consumir cuota adicional y el resultado
es predecible. Inconveniente: las frases largas pueden quedar más telegráficas.

### Desactivar toda la limpieza

```toml
[cleanup]
rules = false
llm = false
```

El texto transcrito se inserta tal cual.

## Inserción

```toml
[insert]
key = ""
paste_delay_ms = 150
restore_clipboard = true
```

| Clave | Por defecto | Qué hace |
| --- | --- | --- |
| `key` | `""` | Atajo de pegado. Vacío = autodetectar según la ventana. |
| `paste_delay_ms` | `150` | Espera antes de pegar, para que el portapapeles esté listo. |
| `restore_clipboard` | `true` | Restaura el contenido anterior del portapapeles. |

Valores de `key`:

- `""`: detecta terminales y usa `ctrl+shift+v`; en el resto, `ctrl+v`.
- `"ctrl+v"`: fuerza el pegado normal.
- `"ctrl+shift+v"`: fuerza el pegado de terminal.
- `"type"`: escribe el texto carácter a carácter con `xdotool`. Útil en
  aplicaciones que no aceptan pegado, pero es más lento y puede perder
  caracteres con textos largos.

Si el pegado llega antes de que la aplicación esté lista, sube
`paste_delay_ms` a `250` o `300`.

## Historial

```toml
[history]
enabled = true
max_entries = 500
pending_days = 7
```

| Clave | Por defecto | Qué hace |
| --- | --- | --- |
| `enabled` | `true` | Guarda cada dictado en `history.jsonl`. |
| `max_entries` | `500` | Entradas máximas; las más antiguas se descartan. |
| `pending_days` | `7` | Días que se conservan los audios fallidos. |

El historial contiene el texto dictado. Está en:

```text
~/.local/state/dictado/history.jsonl
```

con permisos `600`. Para no guardar nada:

```toml
[history]
enabled = false
```

Para borrarlo:

```bash
dictado purge
```

## Notificaciones

```toml
[notify]
enabled = true
```

Muestra avisos al empezar a grabar, al transcribir y al terminar. Si tu
escritorio las tiene desactivadas, no aparecerán aunque esta opción esté en
`true`. En Cinnamon:

```bash
gsettings set org.cinnamon.desktop.notifications display-notifications true
```

## Clave de API

La clave no va en `config.toml`. Vive en:

```text
~/.config/dictado/env
```

con permisos `600` y este formato:

```text
GEMINI_API_KEY=AIza...
```

Para cambiarla:

```bash
dictado config set-key
```

También se puede definir `GEMINI_API_KEY` en el entorno. El programa consulta
primero el archivo y después la variable.

## Variables de entorno

| Variable | Efecto |
| --- | --- |
| `GEMINI_API_KEY` | Clave de API si no está en el archivo. |
| `VISUAL`, `EDITOR` | Editor usado por `dictado config edit`. |
| `DICTADO_HOTKEY_SCRIPT` | Ruta alternativa a `hotkey.sh`. |
| `XDG_CONFIG_HOME` | Cambia la ubicación de la configuración. |
| `XDG_STATE_HOME` | Cambia la ubicación del historial. |
| `XDG_RUNTIME_DIR` | Directorio del estado temporal de grabación. |

`XDG_CONFIG_HOME` y `XDG_STATE_HOME` deben ser rutas absolutas. Si están
vacías o contienen una ruta relativa, se usan `~/.config` y `~/.local/state`.

## Archivos que usa

| Ruta | Contenido | Permisos |
| --- | --- | --- |
| `${XDG_CONFIG_HOME:-$HOME/.config}/dictado/config.toml` | Configuración | `600` |
| `${XDG_CONFIG_HOME:-$HOME/.config}/dictado/env` | Clave de API | `600` |
| `${XDG_CONFIG_HOME:-$HOME/.config}/dictado/opencode-backup.json` | Copia para revertir opencode | `600` |
| `${XDG_STATE_HOME:-$HOME/.local/state}/dictado/history.jsonl` | Texto dictado | `600` |
| `${XDG_STATE_HOME:-$HOME/.local/state}/dictado/pending/` | Audios fallidos | `700` |
| `~/.local/bin/dictado` | Ejecutable | `755` |
| `~/.local/lib/dictado/hotkey.sh` | Gestor de atajos | `755` |
| `$XDG_RUNTIME_DIR/dictado/` | Estado de la grabación en curso | `700` |
