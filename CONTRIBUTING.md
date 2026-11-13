# Contribuir

Gracias por querer mejorar dictado. Este documento resume cómo preparar el
entorno, qué estilo seguir y qué no enviar nunca.

## Antes de empezar

- Busca en las incidencias existentes si el tema ya está tratado.
- Para cambios grandes, abre antes una propuesta y acordamos el enfoque.
- Para errores, incluye la salida de `dictado doctor` **sin tu clave**.

## Preparar el entorno

No hace falta instalar nada especial: el proyecto usa solo la biblioteca
estándar de Python.

```bash
git clone https://github.com/ZintG/dictado.git
cd dictado
make test
make lint
```

Requisitos:

- Python 3.9 o superior.
- Bash.
- `git`.

Las pruebas no necesitan red, micrófono ni clave de API.

## Comprobar los cambios

Antes de enviar una contribución:

```bash
make test           # pruebas unitarias
make lint           # sintaxis de Python y Bash
make check-secrets  # claves, correos y rutas personales
```

Si tocas la instalación, pruébala en un `HOME` temporal:

```bash
mkdir -p /tmp/dictado-prueba
HOME=/tmp/dictado-prueba ./install.sh \
  --non-interactive --no-deps --no-hotkey --no-opencode \
  --prefix /tmp/dictado-prueba/.local
```

Así no tocas tu instalación real.

## Estilo

### Python

- Compatible con Python 3.9: nada de `match`, `tomllib` obligatorio ni tipos
  que solo existan en versiones nuevas.
- Cuatro espacios, líneas de hasta 100 caracteres.
- Nombres de funciones y variables en español cuando describen el dominio
  (`grabar`, `limpiar`, `pegar`), y en inglés cuando son términos técnicos
  (`config`, `payload`, `timeout`).
- Sin dependencias externas.
- Los mensajes de usuario, en español.

### Bash

- `set -euo pipefail` al principio.
- Funciones pequeñas con nombre claro.
- Cita siempre las variables: `"$var"`.
- Comprueba la sintaxis con `bash -n`.
- Si añades una opción al instalador, actualiza `--help` y la documentación.

### Documentación

- La documentación principal está en español.
- `README.en.md` es el resumen en inglés.
- Usa ejemplos copiables y evita rutas absolutas con nombres de usuario.
- Si cambias una opción de configuración, actualiza
  `docs/configuracion.md` y `config/config.example.toml`.

## Añadir reglas de limpieza

1. Añade el patrón junto a los existentes en `bin/dictado`.
2. Añade al menos un caso en `tests/test_cleanup.py`.
3. Comprueba que no rompe los casos existentes:

   ```bash
   make test
   ```

4. Explica en la propuesta qué muletilla o error cubre y un ejemplo real.

## Añadir soporte para un escritorio

`scripts/hotkey.sh` tiene tres acciones por escritorio: `set`, `status` y
`remove`. Para añadir uno nuevo:

1. Crea las tres funciones.
2. Añade el escritorio a `detect_desktop`.
3. Engánchalo en el `case` de las tres acciones.
4. Documenta el mecanismo en `docs/atajos.md`.
5. Pide a alguien con ese escritorio que lo pruebe, o indica claramente que no
   lo has podido verificar.

## Qué no enviar

- Claves de API, tokens o contraseñas.
- Tu `~/.config/dictado/env`.
- Tu `~/.local/state/dictado/history.jsonl`.
- Audios personales.
- Correos electrónicos o rutas con tu nombre de usuario.
- Capturas con texto dictado real.

`make check-secrets` detecta los casos más habituales, pero la revisión final
es tuya.

## Mensajes de commit

Formato corto, en imperativo y en español:

```text
Añade soporte para el atajo en LXQt
Corrige el recorte de silencio con audios cortos
Documenta la integración con opencode
```

Si el cambio es grande, añade un cuerpo explicando el porqué.

## Pull requests

- Una cosa por PR.
- Describe el problema y la solución.
- Indica cómo lo has probado (distribución, escritorio, sesión).
- Mantén la documentación actualizada.
- Acepta que el estilo se ajuste antes de fusionar.

## Licencia

Al contribuir aceptas que tu aportación se publique bajo la licencia MIT del
proyecto.
