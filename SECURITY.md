# Seguridad

## Reportar una vulnerabilidad

No abras una incidencia pública para problemas de seguridad. Usa el
[reporte privado de vulnerabilidades de GitHub](https://github.com/ZintG/dictavoz/security/advisories/new).

Incluye, si puedes:

- Versión de dictado (`dictado --version`).
- Distribución y escritorio.
- Descripción del problema y su impacto.
- Pasos para reproducirlo.
- Una prueba de concepto, si aplica.

Intentaré responder lo antes posible y coordinar la divulgación.

## Qué se considera un problema de seguridad

- Exposición de la clave de API.
- Ejecución de comandos a partir del texto transcrito o de la respuesta de la
  API.
- Escritura de archivos fuera de las rutas esperadas.
- Permisos incorrectos en archivos sensibles.
- Filtración de historial o audio a terceros.
- Inyección de contenido en el portapapeles o en la ventana activa.

## Qué no es un problema de seguridad

- Que el plan gratuito de Gemini use el contenido para mejorar sus productos:
  es una condición del servicio, documentada en `docs/privacidad.md`.
- Que Wayland no permita el pegado automático: es una limitación del protocolo.
- Que un usuario con acceso a tu cuenta de Linux pueda leer tu clave: los
  permisos `600` protegen frente a otros usuarios, no frente a ti.

## Buenas prácticas para usuarios

- No compartas `~/.config/dictado/env`.
- Revoca la clave en Google AI Studio si crees que se ha filtrado.
- Desactiva el historial si dictas información sensible.
- Ejecuta `make check-secrets` antes de publicar un fork.
- Mantén el sistema actualizado.

## Alcance

dictado se ejecuta con los permisos de tu usuario. No usa `sudo` salvo en el
instalador, y solo para instalar paquetes del sistema con el gestor de tu
distribución. El programa en sí nunca se ejecuta como root.
