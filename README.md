# SuperKeys

Global hotkeys for macOS. The command is `super-keys`: it registers the shortcuts and stays running. No Dock icon, no menu bar.

Bindings live in `~/.config/super-keys/bindings.toml`. The first run creates that file if it is missing. Edit it, then run `super-keys` again. [`bindings.toml`](bindings.toml) in this repo is an example. A Swift change still needs a rebuild.

DHH tried something similar (archived): [OMAMAC](https://github.com/omacom-io/omamac).

## Install

```sh
brew install nohype-ai/tap/super-keys
```

Apple silicon Macs on macOS 13 and newer get a bottle. Intel Macs compile from source.

[MacStack](https://macstack.dev) depends on this formula, so installing MacStack installs `super-keys` too.

## Run

```sh
super-keys
```

That registers a login agent and starts it under `launchd`. It comes back at login. Log: `~/Library/Logs/super-keys.log`.

```sh
super-keys stop
```

The first launch needs Input Monitoring. macOS may also ask to allow `super-keys` as a background item.

`super-keys /path/to/bindings.toml` uses that file instead of `~/.config/super-keys/bindings.toml`.

`super-keys --foreground` runs the hotkey loop in this terminal instead of under `launchd`. Starting the agent or `--foreground` stops the other one. Two copies fight over the same shortcuts.

If the bindings file is missing, has no macOS bind, or does not parse, super-keys removes its login agent and exits. No shortcuts stay registered.
