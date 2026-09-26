# SuperKeys: bindings.toml

| | |
|--|--|
| Date | 2026-09-16, revised 2026-09-26 |
| Status | Implemented |
| Config | `~/.config/super-keys/bindings.toml` |

Move key → action mappings out of `createHotKeys()` into one TOML file SuperKeys reads at launch.

## Decisions

- **Default file:** `~/.config/super-keys/bindings.toml`. The first run creates it empty (a comment, no binds) when it is absent. `super-keys /other/bindings.toml` uses that path and does not create the default. The copy in this repo is the example and the test catalog. A personal copy also lives at `NohypeAIStack/macOS/MacStack/super-keys/bindings.toml` for a later MacStack restore. That restore is out of scope.
- **Runtime load.** Edit the TOML, then run `super-keys` again (same path). Swift change → `swift build`. No codegen, no file-watch.
- **⌘ / Super is implicit.** `command` is the key (`a`, `return`, …). `modifiers` are extras (`shift`, `option`, `control`). `command` / `super` / `cmd` in `modifiers` is an error.
- **Closed actions:** `launch`, `open-url`, `finder-open`, `finder-new-file`, `shell`, `applescript`, `open-trash`, `empty-trash`, `sleep`, `toggle-appearance`. Appearance and empty-trash stay AppleScript in Swift. Sleep stays `pmset`. The Xcode bind is `shell` in the TOML.
- **`scope`** is `macos` / `omarchy`. SuperKeys registers only binds whose scope contains `macos`. An Omarchy-only bind is valid and skipped. The Omarchy consumer is out of this work.
- **⌃⌘A stays with SoundSource.** No `audio` bind.
- **Config and registered keys stay the same.** If the file is missing, has no `macos` bind, or does not parse, print the path and the reason, delete the login-agent plist, bootout the job, and exit. No shortcuts stay registered. No `macos` bind exits 0. A broken or missing explicit file exits 2. The launchd process (`--agent`) exits 0 after unloading, because KeepAlive would restart a non-zero exit. The plist is removed first, because bootout can kill that process immediately.
- **`browser` is optional** unless a bind uses `open-url`. That is what makes a new empty file valid.
- **Library:** `dduan/TOMLDecoder` ≥ 0.4.4. Parse with `TOMLTable` (every key is visible), then validate. Missing `id` / `action` is a normal validation error. Syntax and type errors print `TOMLError` (line included).
- **`SuperKeysCore`** holds the types, parser, and path rules. Tests do not link the `@main` executable or HotKey. Core's key allowlist is the ASCII names `HotKey.Key.init?(string:)` accepts. `register` still uses `guard let key = Key(string:)`. If HotKey rejects any macOS bind, the agent is removed and the process exits.
- **CLI stays.** `super-keys`, `super-keys stop`, `super-keys --foreground`, and launchd's `super-keys --agent`. `--help` / `-h` exit 0. Anything else exits 2. There is no `launch-agent.sh`.
- **One change set.** The parser is wired in the same change as the file.

Non-goals: Omarchy generator, README generator, live reload, Hyper key, moving the file into NohypeAIStack, changing `mack update` before this binary is what Homebrew installs.

## Schema

```toml
browser = '/Applications/Brave Browser.app'

[[bind]]
id = "terminal"
group = "launch"            # launch | finder | system
scope = ["macos", "omarchy"]
command = "return"          # enter is accepted and stored as return
# modifiers = ["shift"]     # optional; never command/super/cmd
action = "launch"
app = '/Applications/Ghostty.app'
```

| action | payload |
|--------|---------|
| `launch` | `app` |
| `open-url` | `url` (opened with top-level `browser`) |
| `finder-open` | `app` |
| `finder-new-file` | none |
| `shell` | `argv` (non-empty; `[0]` is the executable) |
| `applescript` | `source` |
| `open-trash` / `empty-trash` / `sleep` / `toggle-appearance` | none |

A payload for a different action is an error (`app` on `sleep`). Unknown action, key, modifier, group, scope, or field is an error. Duplicate `id` or duplicate `(command, modifiers)` is an error. No `[[bind]]` is valid and registers nothing.

The 25 shortcuts are the ones previously registered in `SuperKeys.swift`. The test `catalogMatchesTheCurrentCommands` locks that list. ⌃⌘A is a comment in the TOML, not a bind.

## Wiring

`LaunchAgent` writes `ProgramArguments`: `[binary, "--agent", absolute bindings path]`. Same label `ai.nohype.super-keys`.

`[HotKey]` is held with `withExtendedLifetime` across `app.run()`. HotKey's controller keeps only a weak reference.

The plist records `[binary, "--agent", absolute bindings path]`.

## Apply locally

`~/.config/super-keys/bindings.toml` on this machine is filled with the current shortcuts. Run the new `super-keys` once to point launchd at that file. `mack update` still runs the old bottle until the next release, and that old binary ignores the file.
