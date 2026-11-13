# Atajo global

El atajo es la puerta de entrada a dictado. Por defecto es:

```text
Ctrl+Alt+D
```

Una pulsación empieza a grabar; otra detiene, transcribe y pega. El atajo
funciona con la ventana que tengas activa, sin necesidad de abrir una terminal.

## Comandos

```bash
dictado hotkey status              # ver qué atajo está registrado
dictado hotkey set "Ctrl+Alt+D"    # crearlo o cambiarlo
dictado hotkey set "Ctrl+Shift+Space"
dictado hotkey remove              # quitarlo
```

También puedes usar el gestor directamente:

```bash
DICTADO_BIN="$HOME/.local/bin/dictado" \
  bash ~/.local/lib/dictado/hotkey.sh set "Ctrl+Alt+D"
```

El instalador ya lo hace por ti.

## Cómo se escribe la combinación

Puedes escribirla de varias formas equivalentes:

```text
Ctrl+Alt+D
control+alt+d
<Control><Alt>d
```

Modificadores admitidos:

- `Ctrl` o `Control`
- `Alt`
- `Shift`
- `Super`, `Meta`, `Win` o `Cmd`

La tecla final puede ser una letra, un número, una tecla de función (`F9`) o
`Space`. Evita combinaciones que ya use tu escritorio o tus aplicaciones: si
hay conflicto, el sistema ejecutará una de las dos acciones, no ambas.

## Qué hace internamente

`hotkey.sh` detecta el escritorio con `XDG_CURRENT_DESKTOP` y
`DESKTOP_SESSION`, y elige el mecanismo nativo correspondiente. El comando que
registra siempre es:

```text
~/.local/bin/dictado toggle
```

Antes de añadir nada, busca una entrada cuyo comando contenga `dictado`:

- Si existe, actualiza su combinación.
- Si no existe, busca el primer hueco `customN` libre.
- Añade el hueco a la lista **sin tocar los demás atajos**.

## Cinnamon

Usa `gsettings`, la misma interfaz que la ventana de Preferencias. La lista de
atajos personalizados está en:

```text
org.cinnamon.desktop.keybindings custom-list
```

Y cada atajo en:

```text
org.cinnamon.desktop.keybindings.custom-keybinding:
/org/cinnamon/desktop/keybindings/custom-keybindings/customN/
```

Puedes verlo a mano:

```bash
gsettings get org.cinnamon.desktop.keybindings custom-list
gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ binding
```

Después del cambio, el atajo aparece en **Preferencias → Teclado → Atajos →
Atajos personalizados** con el nombre «Dictado».

## GNOME

Mismo esquema que Cinnamon, pero con otras claves:

```text
org.gnome.settings-daemon.plugins.media-keys custom-keybindings
org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:
/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/customN/
```

También aparece en **Configuración → Teclado → Atajos personalizados**. En
GNOME de Wayland el atajo funciona, pero el pegado automático no.

## XFCE

Usa `xfconf-query` sobre el canal `xfce4-keyboard-shortcuts`:

```bash
xfconf-query -c xfce4-keyboard-shortcuts -l -v | grep dictado
```

El atajo se guarda como una propiedad de tipo cadena en
`/commands/custom/<combinación>`. Aparece en **Configuración → Teclado →
Atajos de teclado**.

## KDE Plasma

KDE no ofrece una interfaz de línea de comandos estable para atajos globales,
así que el soporte es de mejor esfuerzo:

1. Crea `~/.local/share/applications/dictado.desktop`.
2. Escribe la combinación en `kglobalshortcutsrc` con `kwriteconfig5` o
   `kwriteconfig6`.

Si el atajo no se aplica de inmediato, cierra sesión y vuelve a entrar, o
asígnalo a mano en **Preferencias → Atajos → Dictado**.

## MATE, LXQt y otros X11

Si no hay un mecanismo nativo conocido, se usa `xbindkeys`:

```bash
sudo apt install xbindkeys        # Debian, Ubuntu, Mint
sudo dnf install xbindkeys        # Fedora
sudo pacman -S xbindkeys          # Arch
```

`hotkey.sh` añade un bloque delimitado a `~/.xbindkeysrc`, arranca el proceso y
crea un archivo de autostart para que siga funcionando tras iniciar sesión:

```text
# dictado: inicio
"~/.local/bin/dictado toggle"
  Control+Alt+d
# dictado: fin
```

El bloque se puede eliminar sin miedo: `dictado hotkey remove` solo borra lo
que está entre esos dos marcadores.

## Wayland

El atajo se registra igual, pero los compositores Wayland no permiten que un
programa inyecte pulsaciones en otra ventana. Por eso:

- La grabación y la transcripción funcionan.
- El texto se copia al portapapeles.
- Debes pegarlo tú con `Ctrl+V`.

Es una limitación del protocolo de seguridad de Wayland, no de dictado.

## Si el atajo no funciona

1. Comprueba el estado:

   ```bash
   dictado hotkey status
   ```

2. Ejecuta el comando a mano para descartar el programa:

   ```bash
   ~/.local/bin/dictado toggle
   ```

3. Comprueba conflictos con otros atajos del escritorio.

4. Revisa el diagnóstico:

   ```bash
   dictado doctor
   ```

5. Si nada funciona, crea el atajo a mano en la configuración de teclado de tu
   escritorio con el comando `dictado toggle`.

### El atajo desapareció tras actualizar

Algunos escritorios reescriben su lista de atajos al cerrar sesión. Vuelve a
registrarlo:

```bash
dictado hotkey set "Ctrl+Alt+D"
```

### Quiero dos atajos

Puedes crear un segundo atajo manual que ejecute `dictado toggle`, o cambiar la
combinación cuando lo necesites. El gestor mantiene una sola entrada de
dictado; si ejecutas `set` otra vez, actualiza la existente en lugar de
duplicarla.
