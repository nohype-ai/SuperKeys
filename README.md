# SuperKeys

Global shortcuts for macOS, stored in one TOML file.

You name the key, every modifier, and what should happen. `super-keys` registers those shortcuts and stays out of the way: no Dock icon, no menu bar. It comes back at login.

## Install

```sh
brew install nohype-ai/tap/super-keys
super-keys
```

macOS 13 or newer. Apple silicon gets a bottle. Intel Macs compile from source.

The first run creates `~/.config/super-keys/bindings.toml`. That file starts empty, so the agent does not stay running until you add a shortcut and run `super-keys` again.

macOS asks for Input Monitoring the first time. It may also ask to allow `super-keys` as a background item. A shortcut that touches the front Finder window asks for Automation, once.

[MacStack](https://macstack.dev) depends on this formula. Installing MacStack installs `super-keys`.

## A binding

```toml
browser = '/Applications/Safari.app'

[[bind]]
id = "terminal"
group = "launch"
scope = ["macos"]
command = "return"
modifiers = ["command"]
action = "launch"
app = '/Applications/Ghostty.app'

[[bind]]
id = "search"
group = "launch"
scope = ["macos"]
command = "k"
modifiers = ["command", "shift"]
action = "open-url"
url = 'https://kagi.com'
```

That is ⌘↩ for Ghostty, and ⌘⇧K for a URL in Safari. Omit `command` and the shortcut does not use ⌘.

`command` is the key: `a`, `return`, `slash`, `delete`, or any other name [HotKey](https://github.com/soffes/HotKey) accepts. `enter` is stored as `return`. `modifiers` are optional. Each one you want is listed: `command`, `shift`, `option`, `control`.

Edit the file, then run `super-keys` again. The shortcuts in effect are the shortcuts in the file. If the file is missing, has no `macos` bind, or does not parse, SuperKeys removes its login agent and exits. Nothing from an older file stays registered.

[`bindings.toml`](bindings.toml) in this repo is a longer example.

### Fields

| field | required | |
|---|---|---|
| `id` | yes | unique name |
| `group` | yes | `launch`, `finder`, or `system`. For your own sorting. |
| `scope` | yes | `macos`, `omarchy`, or both. SuperKeys registers binds that include `macos`. |
| `command` | yes | the key |
| `modifiers` | no | `command`, `shift`, `option`, `control` |
| `action` | yes | one of the actions below |
| `browser` | for `open-url` | top-level app path. Omit it when no bind opens a URL. |

Two binds cannot share a shortcut. A payload from a different action is an error (`app` on `sleep` is a typo).

### Actions

| action | payload | |
|---|---|---|
| `launch` | `app` | open that application |
| `open-url` | `url` | open the URL in `browser` |
| `finder-open` | `app` | open the front Finder folder in that application |
| `finder-new-file` | | create `_new.md` in the front Finder folder and select it |
| `shell` | `argv` | run a program. The first item is the executable. |
| `applescript` | `source` | run that script |
| `open-trash` | | open `~/.Trash` |
| `empty-trash` | | empty the Trash |
| `sleep` | | put the Mac to sleep |
| `toggle-appearance` | | switch between light and dark mode |

## Commands

```sh
super-keys                          # register the login agent and start it
super-keys stop                     # stop until the next login, or the next super-keys
super-keys --foreground             # run in this terminal instead of under launchd
super-keys /path/to/bindings.toml   # use this file instead
```

`super-keys /path/to/bindings.toml` does not create `~/.config/super-keys/bindings.toml`.

Log: `~/Library/Logs/super-keys.log`

`super-keys` and `super-keys --foreground` both take the shortcuts. Starting one stops the other.

```sh
launchctl print gui/$(id -u)/ai.nohype.super-keys
```

## License

[MIT](LICENSE)

DHH archived a related experiment: [OMAMAC](https://github.com/omacom-io/omamac).
