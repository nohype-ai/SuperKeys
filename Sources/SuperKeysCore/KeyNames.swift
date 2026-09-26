/// ASCII names accepted by `HotKey.Key.init?(string:)`, already lowercased.
/// Emoji and private-use aliases are left out. `enter` is rewritten to `return` before the check.
enum KeyNames {
    static func canonical(_ raw: String) -> String? {
        let lowered = raw.lowercased()
        let name = lowered == "enter" ? "return" : lowered
        guard accepted.contains(name) else { return nil }
        return name
    }

    static let accepted: Set<String> = [
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "zero", "0", "one", "1", "two", "2", "three", "3", "four", "4",
        "five", "5", "six", "6", "seven", "7", "eight", "8", "nine", "9",
        "period", ".", "quote", "\"", "rightbracket", "]", "semicolon", ";",
        "slash", "/", "backslash", "\\", "comma", ",", "equal", "=",
        "grave", "`", "leftbracket", "[", "minus", "-", "section",
        "space", "tab", "return",
        "command", "rightcommand", "option", "rightoption", "control", "rightcontrol",
        "shift", "rightshift", "function", "fn", "capslock",
        "pageup", "pagedown", "home", "end",
        "uparrow", "rightarrow", "downarrow", "leftarrow",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10",
        "f11", "f12", "f13", "f14", "f15", "f16", "f17", "f18", "f19", "f20",
        "keypad0", "keypad1", "keypad2", "keypad3", "keypad4",
        "keypad5", "keypad6", "keypad7", "keypad8", "keypad9",
        "keypadclear", "keypaddecimal", "keypaddivide", "keypadenter",
        "keypadequals", "keypadminus", "keypadmultiply", "keypadplus",
        "escape", "delete", "forwarddelete", "help",
        "volumeup", "volumedown", "mute",
    ]
}
