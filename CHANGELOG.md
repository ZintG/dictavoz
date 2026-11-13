# Historial de cambios

Todas las versiones notables se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[versionado semántico](https://semver.org/lang/es/).

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
