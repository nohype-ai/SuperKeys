# SuperKeys

Global hotkeys for macOS. The command is `super-keys`: it registers the shortcuts and stays running. No Dock icon, no menu bar.

Bindings currently live in `Sources/SuperKeys/SuperKeys.swift`.

DHH tried something similar (archived): [OMAMAC](https://github.com/omacom-io/omamac).

## Install

```sh
brew install nohype-ai/tap/super-keys
```

[MacStack](https://macstack.dev) depends on this formula, so installing MacStack installs `super-keys` too.

## Run

```sh
super-keys
```

Stop it with Ctrl-C. A stack can also keep it running with a LaunchAgent. Log lines go to stdout and stderr.

The first launch needs Input Monitoring, and Login Items permission if `launchd` starts it.
