# Solución de problemas

## Empieza por el diagnóstico

```bash
dictado doctor
```

Revisa cada línea:

- `✓` correcto.
- `!` aviso: el programa puede funcionar, pero algo no está óptimo.
- `✗` fallo: hay que corregirlo.

La última línea resume cuántos fallos y avisos hay. Si pegas la salida en una
incidencia, **oculta tu clave de API**.

## No graba o la grabación está vacía

### «Grabación vacía» o «arecord terminó al arrancar»

Comprueba que el micrófono existe:

```bash
arecord -l
```

Deberías ver una tarjeta con un dispositivo de captura. Prueba a grabar un
segundo:

```bash
arecord -d 1 -f S16_LE -r 16000 -c 1 /tmp/prueba.wav
aplay /tmp/prueba.wav
```

Si no se oye nada, el problema es del sistema de audio, no de dictado.

### Elegir otro micrófono

Averigua el nombre o la tarjeta:

```bash
arecord -L
```

Y cámbialo en `~/.config/dictado/config.toml`:

```toml
[audio]
device = "plughw:1,0"
```

### El micrófono está silenciado

Abre la configuración de sonido del escritorio y sube el nivel de entrada.
Prueba con otra aplicación para descartar el hardware.

### Solo captura el principio

Algunos dispositivos tardan en arrancar. Prueba a subir `min_duration` o a
grabar con `device = "default"`.

## No transcribe

### «falta GEMINI_API_KEY»

Configura la clave:

```bash
dictado config set-key
```

Debe empezar por `AIza`. Se guarda en `~/.config/dictado/env` con permisos
`600`.

### HTTP 400

Suele indicar una petición mal formada. Comprueba:

- Que la clave esté completa y sin espacios.
- Que `stt.model` sea un modelo válido.
- Que `stt.mode` sea `smart` o `verbatim`.
- Que `custom_vocabulary` no tenga entradas vacías.

Vuelve a probar:

```bash
dictado doctor
```

### HTTP 403

La clave no tiene permiso para el modelo o la API no está habilitada en tu
proyecto de Google Cloud. Crea una clave nueva en Google AI Studio y vuelve a
configurarla.

### HTTP 429

Has superado la cuota gratuita. El programa respeta `Retry-After`, reintenta
una vez los límites por minuto y no reintenta si la cuota diaria está agotada.
Espera a que se reinicie la cuota (medianoche del Pacífico para el límite
diario) o revisa los límites de tu cuenta en Google AI Studio. Algunos modelos
del tier gratuito limitan, por ejemplo, a 25 peticiones diarias.

### «sin conexión»

Comprueba la red:

```bash
curl -sS https://generativelanguage.googleapis.com >/dev/null && echo "hay red"
```

Si usas un proxy, configúralo en el entorno antes de lanzar dictado:

```bash
export HTTPS_PROXY="http://tu-proxy:puerto"
```

### «tiempo de espera agotado»

Sube `stt.timeout` en la configuración o usa una grabación más corta. En redes
lentas, 90 segundos puede quedarse corto para audios muy largos.

### «audio demasiado largo para enviarlo inline»

El audio se envía dentro de la petición JSON. Por encima de unos 14 MB
(aproximadamente 7-8 minutos de WAV mono a 16 kHz) se rechaza para no superar
el límite de 20 MB de la API. Divide la grabación en partes más cortas o usa
`dictado transcribe` con fragmentos separados.

### El audio queda en `pending/`

Cuando falla la transcripción, el WAV se conserva para reintentar:

```bash
dictado transcribe ~/.local/state/dictado/pending/rec-20260101-120000.wav
```

Si el error se repite, revisa la clave y la conexión. Los archivos se borran
solos tras `pending_days`.

## El texto se copia pero no se pega

### La ventana cambió

dictado solo pega si la ventana activa sigue siendo la misma que al empezar.
Si cambiaste de ventana mientras hablabas, el texto queda en el portapapeles.
Pega con `Ctrl+V`.

### Wayland

En Wayland no se pueden inyectar pulsaciones en otras ventanas. El texto se
copia y debes pegarlo tú. Es una limitación del protocolo.

### La aplicación no acepta `Ctrl+V`

Prueba a forzar el atajo en la configuración:

```toml
[insert]
key = "ctrl+shift+v"
```

O, si nada funciona, escribe carácter a carácter:

```toml
[insert]
key = "type"
```

`type` es más lento y puede fallar con textos muy largos.

### Falta `xclip` o `wl-clipboard`

```bash
# X11
sudo apt install xclip
# Wayland
sudo apt install wl-clipboard
```

### Se pega el texto anterior

Sube la espera antes de pegar:

```toml
[insert]
paste_delay_ms = 300
```

### Se pega dos veces

Puede haber dos atajos registrados. Comprueba:

```bash
dictado hotkey status
```

Y revisa que no exista otra entrada manual apuntando a `dictado toggle`.

## El atajo no hace nada

1. Comprueba el estado:

   ```bash
   dictado hotkey status
   ```

2. Ejecuta el comando a mano:

   ```bash
   ~/.local/bin/dictado toggle
   ```

   Si funciona, el problema es del atajo; si no, es del programa.

3. Busca conflictos: otro programa puede estar usando la misma combinación.
   Prueba con otra:

   ```bash
   dictado hotkey set "Ctrl+Shift+Space"
   ```

4. Revisa que `~/.local/bin` esté en el `PATH` del escritorio. Algunos
   entornos no leen `~/.profile`; usa la ruta absoluta en el atajo.

5. Si tu escritorio no está soportado, crea el atajo a mano con el comando
   `dictado toggle`. Consulta [`atajos.md`](atajos.md).

## No aparecen las notificaciones

### Cinnamon

Cinnamon puede tener las notificaciones desactivadas globalmente. Aunque
`notify.enabled` sea `true`, no se mostrará nada. Compruébalo:

```bash
gsettings get org.cinnamon.desktop.notifications display-notifications
```

Si devuelve `false`, actívalas:

```bash
gsettings set org.cinnamon.desktop.notifications display-notifications true
```

Este es un caso habitual: el dictado funciona, pero parece que no hace nada
porque no hay aviso de «Grabando» ni «Transcribiendo».

### Notificaciones en pantalla completa

Aunque estén activadas, el escritorio puede ocultarlas cuando una ventana está
en pantalla completa. Sal de la pantalla completa o revisa la configuración de
notificaciones del escritorio.

### `notify-send` no está instalado

```bash
sudo apt install libnotify-bin
```

Puedes desactivar las notificaciones por completo si prefieres no verlas:

```toml
[notify]
enabled = false
```

## El texto sale mal

### Quedan muletillas

Comprueba que la limpieza esté activa:

```toml
[cleanup]
rules = true
llm = true
```

Prueba las reglas sin hablar:

```bash
dictado clean --text "eh, o sea, este, abre el archivo, ¿sabes?"
```

### Se pierden palabras o se inventan

Los modelos de transcripción pueden alucinar con audio ruidoso o muy largo.
Prueba a:

- Acercarte al micrófono.
- Reducir el ruido de fondo.
- Dictar en frases más cortas.
- Añadir nombres propios a `custom_vocabulary`.
- Cambiar `stt.mode` a `verbatim` si `smart` corrige demasiado.

### El pulido cambia el sentido

El pulido se descarta si pierde términos técnicos o cambia demasiado la
longitud, pero puede reescribir frases. Si prefieres el texto más literal:

```toml
[cleanup]
llm = false
```

### El texto sale en otro idioma

Ajusta `stt.language`:

```toml
[stt]
language = "es-ES"
```

### El texto sale sin puntuación

Comprueba que `cleanup.rules` esté activo. Si el modelo devuelve texto sin
puntuación, el pulido con LLM suele arreglarlo en textos largos.

## Problemas de permisos

### «config.toml inválido»

El archivo tiene un error de sintaxis TOML. Abre el editor:

```bash
dictado config edit
```

Y revisa comillas, corchetes y secciones. Si no encuentras el fallo, compara
con `config/config.example.toml`.

### Aviso de permisos en `doctor`

Los archivos sensibles deben ser `600` y el directorio `700`:

```bash
chmod 700 ~/.config/dictado
chmod 600 ~/.config/dictado/config.toml ~/.config/dictado/env
chmod 600 ~/.local/state/dictado/history.jsonl
```

### «no se pudo escribir en el portapapeles»

Falta el binario del portapapeles o no hay sesión gráfica accesible. Si lanzas
dictado por SSH o desde un cron, no hay portapapeles que usar.

## opencode

Si el texto se pega en opencode pero se pierde parte, revisa
`${XDG_CONFIG_HOME:-~/.config}/opencode/cli.json`:

```json
{
  "prompt": {
    "paste": "full"
  }
}
```

El instalador solo modifica ese archivo si ya existe; no lo crea ni crea su
directorio. Si no lo tienes, añade el fragmento a mano. Al desinstalar se
restaura el valor anterior si el instalador guardó una copia; las instalaciones
anteriores no la tienen y conservan el valor actual. Puedes omitir la
integración con `--no-opencode`.

## La primera grabación tarda

La primera llamada a la API puede tardar más por el arranque en frío del
modelo. Es normal. Las siguientes suelen ser más rápidas.

## Ver registros

El programa no escribe un registro persistente, pero puedes ver los errores en
la terminal:

```bash
dictado toggle
dictado status
dictado doctor
```

El estado temporal está en:

```text
$XDG_RUNTIME_DIR/dictado/
```

Y los audios fallidos en:

```text
~/.local/state/dictado/pending/
```

## Reinstalar desde cero

```bash
cd dictavoz
./install.sh --dry-run     # revisa el plan
./install.sh
```

Si sospechas que la configuración está corrupta:

```bash
mv ~/.config/dictado/config.toml ~/.config/dictado/config.toml.bak
./install.sh
```

La clave se conserva. Si tampoco quieres conservarla:

```bash
./uninstall.sh --purge
./install.sh
```

## Sigue sin funcionar

Reúne esta información antes de abrir una incidencia:

1. Distribución y versión.
2. Escritorio y versión.
3. Sesión: X11 o Wayland.
4. Salida de `dictado --version`.
5. Salida de `dictado doctor` (sin la clave).
6. Qué esperabas que pasara y qué pasó.
7. Los pasos exactos para reproducirlo.

Puedes abrir la incidencia en:

```text
https://github.com/ZintG/dictavoz/issues
```
