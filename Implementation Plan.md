# SuperKeys: bindings.toml

| | |
|--|--|
| Date | 2026-09-16 |
| Status | Plan — not implemented |
| Config | `general/key commands/bindings.toml` |

Move key → action mappings out of `createHotKeys()` into one TOML file SuperKeys reads at launch.

## Decisions

- **One file**, sibling of this package: `general/key commands/bindings.toml`. Not in `Sources/`, not in `~/.config`.
- **Runtime load.** Edit TOML → `./launch-agent.sh`. Swift change → `./build.sh`. No codegen, no file-watch.
- **⌘ / Super is implicit.** TOML `command` is the key (`a`, `return`, …); `modifiers` are extras (`shift`, `option`, `control`). Putting `command`/`super`/`cmd` in `modifiers` is an error.
- **Closed actions**, not a script: `launch`, `open-url`, `finder-open`, `finder-new-file`, `shell`, `applescript`, `open-trash`, `empty-trash`, `sleep`, `toggle-appearance`.
- **`scope`** is `macos` / `omarchy`. SuperKeys registers only binds whose scope contains `macos`. Omarchy consumer is out of this work; the field stays so one file can serve both later.
- **⌃⌘A stays with SoundSource** (its own prefs). README already says that. Do not add an `audio` bind.
- **Stay alive on bad config.** Log to stderr, register nothing, `app.run()`. Exiting non-zero would KeepAlive-loop. Bad argv (no path) is exit 2 — the agent always passes the path.
- **Library:** `dduan/TOMLDecoder` ≥ 0.4.4 (Codable, no C++ interop). Parse/validate in a `SuperKeysCore` library so tests do not touch the `@main` executable.
- **One PR.** Parser-without-wiring is two sources of truth.
- **First apply:** `./build.sh` once after pull. `mack update` alone would rewrite the plist onto the *old* binary, which ignores argv.

Non-goals: Omarchy generator, README generator, live reload, Hyper key, Xcode `.app` / `SMAppService`, ArgumentParser, new launchd label.

## Layout

```
general/key commands/
  bindings.toml                 # NEW — source of truth
  launch-agent.sh               # ProgramArguments [bin, bindings.toml]
  SuperKeys/
    Sources/SuperKeysCore/      # types, parse, validate
    Sources/SuperKeys/          # main, HotKey, existing helpers
    Tests/SuperKeysCoreTests/
```

README tables remain documentation. If they disagree with TOML, trust TOML.

## Schema

```toml
browser = "/Applications/Brave Browser.app"

[[bind]]
id = "terminal"
group = "launch"                 # launch | finder | system
scope = ["macos", "omarchy"]
command = "return"
# modifiers = ["shift"]          # optional; never include command/super
action = "launch"
app = "/Applications/Ghostty.app"
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

Payload for a *different* action is an error (`app` on `sleep` is a typo). Unknown action/key/modifier/group/scope → error. Duplicate `id` or duplicate `(command, modifiers)` → error. Empty `[[bind]]` is valid (register 0).

`command` is lowercased. Alias `enter` → `return`. Accept names `HotKey.Key.init?(string:)` understands. Allowlist in Core is a preview; `register` must `guard let key = Key(string:)` — never `!`. If HotKey rejects any bind, register **nothing**.

Decode into a raw snapshot with **optional** fields, then validate. Missing `browser`/`id`/`action` is `.invalid`, not Codable `keyNotFound`. Print underlying `TOMLError` (line if present), not a raw `DecodingError`.

## Wiring

LaunchAgent: `super-keys /abs/path/bindings.toml` (path baked by `launch-agent.sh` the same way the binary path already is). Refuse to rewrite the plist if `bindings.toml` is missing. Same label `ai.nohype.super-keys`.

CLI: one positional path; `--help`/`-h` stdout exit 0; anything else stderr exit 2. No default path.

Retain `[HotKey]` with `withExtendedLifetime(hotKeys) { app.run() }`. HotKey’s controller holds a weak ref; `_ = hotKeys` can unregister everything before the run loop.

`run(_ argv: [String])`: `executableURL = argv[0]`, `arguments = argv.dropFirst()`. Appearance / empty-trash AppleScript stays in Swift (portable action name). Xcode bind stays `shell` in TOML.

## Catalog (25 current `HotKey` calls)

⌘/Super implicit. No `audio` / ⌃⌘A.

| id | group | scope | command | mods | action | payload |
|----|-------|-------|---------|------|--------|---------|
| terminal | launch | both | return | | launch | Ghostty |
| browser | launch | both | return | shift | launch | Brave |
| ai-assistant | launch | both | a | shift | open-url | https://grok.com |
| email | launch | both | e | shift | launch | Mail |
| finder | launch | both | f | shift | launch | Finder |
| obsidian | launch | both | o | shift | launch | Obsidian |
| music | launch | both | m | shift | launch | Music |
| music-secondary | launch | both | m | shift, option | open-url | https://music.youtube.com |
| passwords | launch | both | slash | shift | launch | Passwords |
| write | launch | both | w | shift | launch | Typora |
| youtube | launch | both | y | shift | open-url | YouTube subscriptions |
| develop | launch | both | d | shift | launch | Zed |
| git-client | launch | both | g | shift | launch | Fork |
| talk | launch | both | t | shift | open-url | https://web.telegram.org |
| develop-secondary | launch | macos | d | shift, option | shell | `zsh -c` xcode-select open |
| system-settings | launch | macos | s | shift | launch | System Settings |
| talk-secondary | launch | macos | t | shift, option | launch | WhatsApp |
| trash | launch | macos | delete | shift | open-trash | |
| finder-terminal | finder | macos | return | control | finder-open | Ghostty |
| finder-develop | finder | macos | d | shift, control | finder-open | Zed |
| finder-new-file | finder | macos | f | shift, control | finder-new-file | |
| finder-write | finder | macos | w | shift, control | finder-open | Typora |
| appearance | system | macos | d | control | toggle-appearance | |
| sleep | system | macos | s | control | sleep | |
| empty-trash | system | macos | delete | control | empty-trash | |

Tests: parse the real `bindings.toml` via `#filePath` walk; expect **exactly these 25 ids**, all with `macos` in scope, unique shortcuts, `audio` absent. Fixtures for invalid TOML / unknown action / duplicate shortcut / missing `browser`.

## Checklist

1. `bindings.toml` with the 25 rows + `browser` + a comment that ⌃⌘A is SoundSource.
2. `SuperKeysCore` + `TOMLDecoder` + Swift Testing.
3. SuperKeys: argv, load, dispatch, `withExtendedLifetime`; delete hardcoded `createHotKeys()` list and `browserPath`.
4. `launch-agent.sh` second ProgramArgument; fail if TOML missing.
5. README: edit TOML → `./launch-agent.sh`; first-time `./build.sh`; two instances still fight.
