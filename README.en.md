# dictado

Global voice dictation for Linux with automatic text cleanup.

Press a hotkey, speak, press it again, and clean text appears in the window you
were using: no filler words, proper punctuation and capitalisation, and
technical terms left intact. It works on any Linux desktop. Automatic pasting
is available on X11; on Wayland the text is placed on the clipboard.

```
global hotkey → arecord → silence trim → Gemini → local rules → paste
```

> The main documentation is in Spanish: [`README.md`](README.md).
> This file is a complete English summary.

## What it does

1. Records with `arecord` at 16 kHz mono.
2. Trims leading and trailing silence with `ffmpeg`.
3. Transcribes with `gemini-3.5-transcribe` in `smart` mode using your language
   and a custom vocabulary.
4. Cleans the text locally: fillers, repetitions, false starts, punctuation,
   capitalisation and spacing.
5. Polishes long texts with `gemini-3.5-flash-lite`, validating the result. If
   technical tokens are lost or the length changes too much, the polished
   version is discarded.
6. Copies to the clipboard and pastes into the window that was active when you
   started.

## Requirements

- Linux with X11 or Wayland.
- Python 3.9+ (`python3-tomli` before 3.11).
- `arecord` (alsa-utils) and `notify-send` (libnotify).
- `ffmpeg` and `ffprobe` (recommended, for silence trimming).
- X11: `xclip` and `xdotool`. Wayland: `wl-clipboard`.
- A free Google AI Studio API key.

The installer detects `apt`, `dnf`, `pacman`, `zypper` or `apk` and installs
what is missing.

## Install

```bash
git clone https://github.com/ZintG/dictado.git
cd dictado
./install.sh
```

The installer runs seven steps: system check, dependencies, files, API key,
configuration, global hotkey, and opencode integration plus diagnostics.

Options:

```text
--prefix DIR         install prefix (default ~/.local)
--hotkey COMBO       shortcut (default Ctrl+Alt+D)
--non-interactive    no prompts; reads GEMINI_API_KEY
--dry-run            show the plan without changing anything
--no-deps            skip system packages
--no-hotkey          skip the global shortcut
--no-opencode        leave opencode configuration untouched
--uninstall          remove the program, keep your data
--purge              with --uninstall, also delete data and config
```

## API key

Create a free key at <https://aistudio.google.com/apikey> (Create API key).
The installer asks for it without echoing and stores it in
`~/.config/dictado/env` with mode `600`. It is never committed to the
repository and is only sent to the Gemini API.

Change it later with:

```bash
dictado config set-key
```

## Daily use

```bash
dictado toggle            # start or stop (what the hotkey runs)
dictado start             # start recording
dictado stop              # stop, transcribe, clean and paste
dictado status            # is it recording?
dictado doctor            # full environment diagnostics
dictado history           # recent dictations
dictado purge             # delete history and pending audio
```

Testing the cleanup without speaking:

```bash
dictado clean --text "eh, o sea, abre el archivo, ¿sabes?"
dictado clean --file note.txt
dictado transcribe sample.wav
```

## Configuration

The file is `~/.config/dictado/config.toml`, applied on the next dictation.
A commented example lives in [`config/config.example.toml`](config/config.example.toml).

```bash
dictado config show
dictado config edit
dictado config path
```

The most useful settings are `stt.language`, `stt.custom_vocabulary`,
`audio.device`, `cleanup.llm`, `insert.key` and `history.enabled`.

### Global hotkey

```bash
dictado hotkey status
dictado hotkey set "Ctrl+Alt+D"
dictado hotkey set "Ctrl+Shift+Space"
dictado hotkey remove
```

| Desktop | Mechanism |
| --- | --- |
| Cinnamon | `gsettings` (`custom-list`) |
| GNOME | `gsettings` (`custom-keybindings`) |
| XFCE | `xfconf-query` |
| KDE Plasma | `.desktop` file + `kglobalshortcutsrc` (best effort) |
| MATE, LXQt, other X11 | `xbindkeys` fallback |

Existing shortcuts are preserved: the dictado entry is appended to the list,
never replacing it.

## X11 vs Wayland

- **X11**: full support. The active window is remembered, `xdotool` pastes the
  text, and terminals are detected (`ctrl+shift+v`) versus everything else
  (`ctrl+v`).
- **Wayland**: the hotkey and transcription work, but the text is only copied
  to the clipboard. Compositors do not allow injecting keystrokes into other
  windows without special permissions. Paste manually with `Ctrl+V`.

## Privacy

- Audio is sent to the Gemini API for transcription.
- Dictated text is stored in `~/.local/state/dictado/history.jsonl` with mode
  `600`. You can disable or delete it.
- Failed audio is kept for a few days in `~/.local/state/dictado/pending` and
  pruned automatically.
- The key lives in `~/.config/dictado/env` with mode `600`.
- The free Gemini tier may use content to improve Google products. Check
  Google's terms before dictating sensitive information.

See [`docs/privacidad.md`](docs/privacidad.md) (Spanish).

## Troubleshooting

| Symptom | Usual cause | Fix |
| --- | --- | --- |
| No "Transcribing" notification | Notifications disabled in Cinnamon | `gsettings set org.cinnamon.desktop.notifications display-notifications true` |
| Text is copied but not pasted | Focus changed, or Wayland | Return to the window and press `Ctrl+V` |
| "could not write to clipboard" | `xclip` or `wl-clipboard` missing | Install it with your package manager |
| Hotkey does nothing | Another app uses it, or it was not registered | `dictado hotkey status` and `dictado doctor` |
| API 400/403 | Bad key or missing permissions | `dictado config set-key` |
| Recording is empty | Wrong microphone | Change `audio.device` (`arecord -l`) |

Full guide: [`docs/solucion-problemas.md`](docs/solucion-problemas.md) (Spanish).

## Development

```bash
make test           # unit tests
make lint           # Python and Bash syntax
make check-secrets  # scan for keys and personal data
```

Tests need no network or microphone.

## Uninstall

```bash
./uninstall.sh            # remove program and hotkey, keep your data
./uninstall.sh --purge    # also delete configuration and history
```

## License

MIT. See [`LICENSE`](LICENSE).
