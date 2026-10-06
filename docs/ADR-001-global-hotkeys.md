# ADR-001: Global hotkeys for launching apps and URLs

**Status:** Accepted  
**Date:** 2026-09-15  
**Context:** SuperKeys PoC (Swift package executable)

## Decision

Use **Carbon `RegisterEventHotKey`** via **[soffes/HotKey](https://github.com/soffes/HotKey)** in a long-lived Swift process (`NSApplication.shared` + `.prohibited`). Bindings live in code. Actions are `NSWorkspace` launches and URL opens (optionally pinned to Brave).

## Requirements that drove this

- Global chords only: ⌘ ⌥ ⌃ ⇧ + one key (e.g. ⇧⌘↩, ⇧⌘A).
- Combo must be **swallowed** (front app does not also receive it).
- Launch apps and websites. No remaps, sequences, hold, or lone modifiers.
- Config that can live in git (no Raycast UI export).
- No Accessibility / Input Monitoring if avoidable.
- Low idle cost; stay running without a Dock icon.

## Why Carbon (layer 4), not an event tap (layer 2)

macOS delivers hotkeys roughly in this order:

1. DriverKit (Karabiner)
2. `CGEventTap`
3. System reserved shortcuts
4. **Carbon hotkey table** ← we register here
5. Frontmost app (menus, text fields)

Carbon is enough for modifier + one key. It consumes the combo, needs no Accessibility, and wakes only on a registered chord. An event tap sees every key, needs TCC, and is the right tool only for leader keys, left/right modifiers, or pass-through.

## Why HotKey, not a thicker wrapper

| Option | Role | Why not (for us) |
|---|---|---|
| **soffes/HotKey** | Thin Carbon wrapper, hardcoded combo + handler | **Chosen.** Matches a fixed map. Quiet repo; Carbon is stable. |
| sindresorhus/KeyboardShortcuts | Same Carbon layer + recorder + UserDefaults | Right if bindings are user-editable in a settings UI. Extra surface we do not need. |
| Raw `RegisterEventHotKey` | No dependency | Fine later; ~20–40 lines. HotKey is the 7-line PoC. |

## Alternatives considered

### Raycast
Where this started. Fast and reliable for the same Carbon-class shortcuts. Import/export is UI- and subscription-shaped; not a git-friendly source of truth. Rejected as the *config store*, not as a product judgment.

### Keyboard Cowboy ([zenangst/KeyboardCowboy](https://github.com/zenangst/KeyboardCowboy))
Tap-first (`MachPort` / `CGEventTap`). More power than we use (sequences, hold, context). Config is JSON under `~/.config/keyboardcowboy/` — backupable, not a documented CLI. UI was unusable here (hangs, list selection, context menu always hitting the first workflow). Overkill and blocked by the editor.

### skhd
Plain-text `skhdrc`, Carbon-class bindings, scriptable. Closest config-file cousin. We wanted Swift + `NSWorkspace` in one binary instead of a daemon + shell.

### Hammerspoon
Lua, very capable, slow upstream, ObjC-era host. Fine for power users; not the modern Swift path we wanted.

### Karabiner-Elements
Layer 1. Correct for remaps and complex modifications. Heavier, Accessibility/driver, JSON that is not “open this URL.” Wrong layer.

### KeyboardShortcuts package in a background agent
Same mechanism as HotKey. Choose it if we add an in-app recorder. Until then it persists to defaults instead of the source file.

## Runtime shape we kept

- Xcode 27 **Swift package → Executable** (`swift package init --type executable`), not **Command Line Tool** (`--type tool` / ArgumentParser).
- Process must **stay alive**. `NSApplication.shared.run()` (AppKit is already pulled in by HotKey). `.prohibited` = no Dock.
- `HotKey` instances must be **retained** (array in `main`) or Carbon unregisters on `deinit`.
- First successful Carbon registrant owns the combo; the focused app does not win.
- System reserved shortcuts can still preempt us.

## Revisit when

- Need leader keys, double-tap, hold, modifier-only, or left vs right ⌘/⌥ → event tap (or Karabiner).
- Want a click-to-record UI → KeyboardShortcuts.
- Want a plain-text map without compiling → skhd.
- HotKey bit-rots on a new OS → vendor Carbon ourselves or switch to KeyboardShortcuts (same layer, more maintained).
