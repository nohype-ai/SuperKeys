# SuperKeys

Global hotkeys for macOS. The command is `super-keys`: it registers the shortcuts and stays running. No Dock icon, no menu bar.

Bindings currently live in `Sources/SuperKeys/SuperKeys.swift`.

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

`super-keys --foreground` runs the hotkey loop in this terminal instead of under `launchd`.
