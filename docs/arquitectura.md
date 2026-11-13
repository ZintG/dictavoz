# Arquitectura

dictado es un programa pequeño con una idea central: grabar, transcribir,
limpiar y pegar, sin que el usuario cambie de ventana ni de contexto.

```text
┌──────────────┐
│ atajo global │  Ctrl+Alt+D (o el que elijas)
└──────┬───────┘
       │  dictado toggle
       ▼
┌──────────────┐     ┌──────────┐     ┌──────────────┐
│   arecord    │────▶│  ffmpeg  │────▶│    Gemini    │
│  16 kHz mono │     │ recorte  │     │ transcripción│
└──────────────┘     └──────────┘     └──────┬───────┘
                                             │ texto
                                             ▼
                                      ┌──────────────┐
                                      │ reglas local │
                                      └──────┬───────┘
                                             │ ¿texto largo?
                                    ┌────────┴────────┐
                                    ▼                 ▼
                             ┌────────────┐    ┌────────────┐
                             │  pulido    │    │  sin pulir │
                             │  con LLM   │    └─────┬──────┘
                             └─────┬──────┘          │
                                   └────────┬────────┘
                                            ▼
                                     ┌─────────────┐
                                     │ portapapeles│
                                     └──────┬──────┘
                                            ▼
                                     ┌─────────────┐
                                     │ pegado en   │
                                     │ la ventana  │
                                     └─────────────┘
```

## Piezas del repositorio

| Archivo | Responsabilidad |
| --- | --- |
| `bin/dictado` | Todo el programa: CLI, audio, API, limpieza, inserción e historial. |
| `scripts/hotkey.sh` | Registra el atajo en Cinnamon, GNOME, XFCE, KDE y xbindkeys. |
| `install.sh` | Instalación interactiva, dependencias, clave y diagnóstico. |
| `uninstall.sh` | Atajo a `install.sh --uninstall`. |
| `config/config.example.toml` | Configuración comentada. |
| `tests/test_cleanup.py` | Pruebas de reglas y validación del pulido. |
| `docs/` | Esta documentación. |

No hay dependencias de Python externas: solo la biblioteca estándar. La
lectura de TOML usa `tomllib` en Python 3.11+ o `tomli` en versiones anteriores.

## El ciclo de una pulsación

1. El escritorio ejecuta `dictado toggle`.
2. Si no hay grabación en curso, `cmd_start`:
   - comprueba que `arecord` exista;
   - lanza `arecord` en segundo plano;
   - espera 250 ms para detectar fallos tempranos del micrófono;
   - guarda en el estado el PID, el archivo WAV, la hora y la ventana activa.
3. Si ya hay grabación, `cmd_stop`:
   - envía `SIGINT` a `arecord` y espera a que cierre el WAV;
   - descarta la grabación si pesa menos de 1 KB;
   - procesa el audio;
   - borra el WAV original y el recortado si todo va bien.

El estado vive en `$XDG_RUNTIME_DIR/dictado/state.json`, con permisos `600`.
Si el proceso muere, el archivo queda huérfano; `dictado status` permite
detectarlo y `cmd_stop` lo limpia.

## Audio

`arecord` graba WAV mono a 16 kHz con formato `S16_LE`. Ese formato es
suficiente para voz y mantiene el archivo pequeño: un minuto ronda 1,8 MB.

`trim_silence` usa `ffmpeg` con el filtro `silenceremove` para quitar el
silencio inicial y final. Si `ffmpeg` no está, se envía el audio completo.

`audio_duration` consulta `ffprobe` y, si no está, calcula la duración a partir
de la cabecera del WAV.

## Transcripción

Se usa el modelo `gemini-3.5-transcribe` de la API de interacciones de Gemini:

```text
POST https://generativelanguage.googleapis.com/v1beta/interactions
x-goog-api-key: <clave>
```

El audio se envía en línea, codificado en base64, junto con:

- `store: false`, para no retener la interacción en la API.
- `mode`: `smart` o `{"type": "verbatim"}`.
- `language_codes`: el idioma configurado.
- `custom_vocabulary`: los términos propios.

El envío inline se rechaza si el WAV supera 14 MB (aproximadamente 7-8 minutos
de audio mono a 16 kHz), para no llegar al límite de 20 MB de la petición.

La respuesta se lee de `output_text`; si no está, se recorren los `steps` y se
concatenan los fragmentos de texto.

### Reintentos

`api_post` reintenta una vez los errores 500, 502, 503 y 504 y los fallos de
red. Para 429 respeta `Retry-After`; si la espera supera un minuto, considera
que la cuota diaria está agotada y no reintenta. Los errores 400 y 403 no se
reintentan: suelen indicar clave inválida o petición mal formada.

### Mensajes de error

`api_error_message` acepta tanto `{"error": {...}}` como listas de errores, y
extrae el mensaje más útil sin volcar la respuesta completa.

## Limpieza por reglas

`clean_rules` es determinista y no depende de la red. Aplica, en orden:

1. Normaliza espacios dentro de cada línea y conserva los saltos de línea.
2. Elimina muletillas duras («eh», «o sea», «este»).
3. Elimina coletillas interrogativas («¿sabes?», «¿no?»).
4. Elimina muletillas de cláusula conservando el corte de frase.
5. Corrige falsos comienzos («quiero que, añadas»).
6. Colapsa palabras y frases repetidas.
7. Ajusta puntuación, comas y espacios.
8. Baja conjunciones intercaladas.
9. Pone mayúscula inicial y tras cada punto.
10. Añade punto final si el texto tiene seis palabras o más y no parece un
    comando.

`looks_like_command` evita capitalizar y puntuar líneas que empiezan por
`git`, `npm`, `sudo`, `docker` y similares: son comandos, no prosa.

## Pulido con LLM

`should_polish` decide si merece la pena llamar al modelo:

- el texto supera `llm_min_chars`, o
- tiene al menos `llm_min_sentences` frases, o
- quedan repeticiones evidentes.

El modelo recibe un `system_instruction` que le prohíbe añadir información,
responder al contenido o usar markdown. Devuelve solo el texto final. La
petición usa `store: false`, `thinking_level: "minimal"` y un límite de salida
proporcional a la longitud del texto. Si la interacción no termina con estado
`completed`, se descarta el pulido y se usa el texto de las reglas.

`valid_polish` es la red de seguridad. Rechaza la respuesta si:

- está vacía;
- empieza por una fórmula conversacional;
- contiene bloques de código;
- su longitud se sale de `ratio_min`/`ratio_max`;
- ha perdido algún término técnico detectado en el original.

Los términos técnicos se extraen con patrones: rutas, URLs, banderas `--flag`,
identificadores `snake_case` y `camelCase`, y nombres de archivo con extensión
conocida. Si el pulido no pasa la validación, se usa el texto de las reglas y
se muestra un aviso en el historial.

## Inserción

`insert_text`:

1. Guarda el portapapeles anterior si `restore_clipboard` está activo.
2. Escribe el texto con `xclip` (X11) o `wl-copy` (Wayland).
3. En Wayland termina aquí: el texto queda en el portapapeles.
4. En X11 comprueba que la ventana activa siga siendo la misma y siga viva.
5. Envía el atajo con `xdotool`:
   - `ctrl+shift+v` si la ventana es una terminal conocida;
   - `ctrl+v` en el resto;
   - o lo que diga `insert.key`.
6. Restaura el portapapeles anterior en un proceso aparte, para no borrar el
   texto antes de que la aplicación lo pegue.

La restauración se hace con el subcomando oculto `_restore-clipboard`, que lee
el texto guardado y lo vuelve a escribir tras el retardo configurado en
`paste_delay_ms` (con un mínimo de 1,5 s). Si el portapapeles anterior contenía
datos binarios, se deja como estaba.

## Atajos

`hotkey.sh` es un adaptador, no un daemon. Se ejecuta en la instalación o
cuando el usuario cambia el atajo. Detecta el escritorio y llama al mecanismo
nativo:

- `gsettings` para Cinnamon y GNOME;
- `xfconf-query` para XFCE;
- `.desktop` + `kglobalshortcutsrc` para KDE;
- `xbindkeys` para el resto de X11.

La lógica común busca una entrada existente de dictado, reutiliza su hueco y
conserva el resto de la lista. Eso evita duplicados y no pisa atajos ajenos.

## Historial y datos

Cada dictado correcto añade una línea JSON a `history.jsonl`:

```json
{
  "ts": "2026-01-01T12:00:00+00:00",
  "duration_s": 4.2,
  "raw": "texto del modelo",
  "rules": "texto tras las reglas",
  "final": "texto insertado",
  "stt": "gemini-3.5-transcribe",
  "stt_ms": 1200,
  "llm": "gemini-3.5-flash-lite",
  "llm_ms": 800,
  "warning": null,
  "inserted": true
}
```

El historial se rota al superar `max_entries`. Los audios que fallan se copian
a `pending/` y se borran tras `pending_days`.

## Decisiones de diseño

- **Un solo archivo ejecutable**: facilita la instalación, la copia y la
  auditoría. No hay paquetes ni entorno virtual.
- **Gemini como único backend en la v1**: reduce la superficie de configuración
  y permite ajustar bien el modo `smart` y el vocabulario. La interfaz está
  aislada en `transcribe`, así que añadir otro backend es acotado.
- **Reglas antes que LLM**: la limpieza barata y predecible se hace siempre; el
  modelo solo pule lo que merece la pena.
- **Validación estricta del pulido**: un texto dictado nunca debe empeorar por
  una respuesta creativa del modelo.
- **Atajo nativo siempre que se pueda**: evita daemons y funciona con el
  escritorio real del usuario. `xbindkeys` queda como último recurso.
- **Wayland sin promesas falsas**: se copia al portapapeles y se documenta la
  limitación en lugar de depender de extensiones frágiles.

## Extender dictado

Puntos de entrada razonables:

- **Otro backend de transcripción**: implementa una función con la misma firma
  que `transcribe` y selecciónala en `cfg["stt"]["backend"]`.
- **Otras reglas**: añade patrones junto a los existentes y cubre el caso en
  `tests/test_cleanup.py`.
- **Otro escritorio**: añade un adaptador en `scripts/hotkey.sh` con las
  acciones `set`, `status` y `remove`.
- **Otra integración de pegado**: amplía `detect_paste_key` o usa `insert.key`.

Antes de enviar cambios, ejecuta:

```bash
make test
make lint
make check-secrets
```
