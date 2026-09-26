import Foundation
import Testing
@testable import SuperKeysCore

@Test func catalogMatchesTheCurrentCommands() throws {
    let bindings = try Bindings.load(contentsOf: catalogPath())
    #expect(bindings.browser == "/Applications/Brave Browser.app")
    #expect(bindings.macosBinds.count == 25)
    #expect(bindings.binds.map(\.id) == expectedRows.map { String($0.split(separator: " | ")[0]) })
    #expect(bindings.binds.allSatisfy { $0.scope.contains(.macos) })
    #expect(!bindings.binds.contains { $0.id == "audio" })

    let shortcuts = bindings.binds.map { "\($0.command)|\($0.modifiers.map(\.rawValue).joined(separator: "+"))" }
    #expect(Set(shortcuts).count == shortcuts.count)
    #expect(bindings.binds.map(row).joined(separator: "\n") == expectedRows.joined(separator: "\n"))
}

@Test func invalidTOMLIncludesTheLine() throws {
    let error = try #require(throws: BindingsError.self) {
        try Bindings.load("browser = '/Applications/Brave Browser.app'\n[[bind\n")
    }
    #expect(error.message.contains("Line"))
}

@Test func unknownActionIsRejected() throws {
    let error = try #require(throws: BindingsError.self) {
        try Bindings.load(bind(action: "action = 'nope'"))
    }
    #expect(error.message.contains("unknown action 'nope'"))
}

@Test func duplicateShortcutIsRejected() throws {
    let error = try #require(throws: BindingsError.self) {
        try Bindings.load("""
        browser = '/Applications/Brave Browser.app'
        [[bind]]
        id = "one"
        group = "launch"
        scope = ["macos"]
        command = "a"
        action = "sleep"
        [[bind]]
        id = "two"
        group = "launch"
        scope = ["macos"]
        command = "a"
        action = "sleep"
        """)
    }
    #expect(error.message.contains("duplicate shortcut"))
}

@Test func emptyFileHasNoBindings() throws {
    let bindings = try Bindings.load("")
    #expect(bindings.browser == nil)
    #expect(bindings.macosBinds.isEmpty)
    let template = try Bindings.load(BindingsFile.emptyTemplate)
    #expect(template.macosBinds.isEmpty)
}

@Test func openURLRequiresBrowser() throws {
    let error = try #require(throws: BindingsError.self) {
        try Bindings.load("""
        [[bind]]
        id = "ai"
        group = "launch"
        scope = ["macos"]
        command = "a"
        action = "open-url"
        url = "https://grok.com"
        """)
    }
    #expect(error.message.contains("open-url requires browser"))
}

@Test func payloadForAnotherActionIsRejected() throws {
    let error = try #require(throws: BindingsError.self) {
        try Bindings.load(bind(action: """
        action = "sleep"
        app = '/Applications/Ghostty.app'
        """))
    }
    #expect(error.message.contains("sleep does not take app"))
}

@Test func modifiersAreExplicit() throws {
    let plain = try Bindings.load(bind(action: "action = 'sleep'"))
    #expect(plain.binds.first?.modifiers == [])

    let shifted = try Bindings.load(bind(action: """
    modifiers = ["shift"]
    action = "sleep"
    """))
    #expect(shifted.binds.first?.modifiers == [.shift])

    let commanded = try Bindings.load(bind(action: """
    modifiers = ["shift", "command"]
    action = "sleep"
    """))
    #expect(commanded.binds.first?.modifiers == [.command, .shift])
}

@Test func enterIsStoredAsReturn() throws {
    let bindings = try Bindings.load(bind(action: "action = 'sleep'", command: "enter"))
    #expect(bindings.binds.first?.command == "return")
}

@Test func emptyBindListIsValid() throws {
    let bindings = try Bindings.load("browser = '/Applications/Brave Browser.app'\n")
    #expect(bindings.binds.isEmpty)
    #expect(bindings.macosBinds.isEmpty)
}

@Test func omarchyOnlyBindIsNotMacOS() throws {
    let bindings = try Bindings.load(bind(action: "action = 'sleep'", scope: ["omarchy"]))
    #expect(bindings.binds.count == 1)
    #expect(bindings.macosBinds.isEmpty)
}

@Test func defaultPathIsTheConfigDirectory() {
    #expect(
        BindingsFile.defaultPath(homeDirectory: "/Users/seb")
            == "/Users/seb/.config/super-keys/bindings.toml"
    )
    #expect(
        BindingsFile.resolve(argument: nil, currentDirectory: "/tmp", homeDirectory: "/Users/seb")
            == "/Users/seb/.config/super-keys/bindings.toml"
    )
    #expect(
        BindingsFile.resolve(argument: "mine.toml", currentDirectory: "/repo", homeDirectory: "/Users/seb")
            == "/repo/mine.toml"
    )
}

@Test func missingDefaultFileIsCreatedEmpty() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let loaded = BindingsFile.load(argument: nil, currentDirectory: "/tmp", homeDirectory: home.path)
    guard case .halt(let message, let code) = loaded else {
        Issue.record("expected an empty config to stop")
        return
    }
    #expect(code == 0)
    #expect(message.contains(home.appendingPathComponent(".config/super-keys/bindings.toml").path))
    #expect(message.contains("created"))
    #expect(message.contains("no macos bindings"))
}

@Test func missingExplicitPathDoesNotCreateTheDefault() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let loaded = BindingsFile.load(
        argument: "/tmp/super-keys-does-not-exist.toml",
        currentDirectory: "/tmp",
        homeDirectory: home.path
    )
    guard case .halt(let message, let code) = loaded else {
        Issue.record("expected a missing file to stop")
        return
    }
    #expect(code == 2)
    #expect(message.contains("/tmp/super-keys-does-not-exist.toml"))
    #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".config").path))
}

@Test func brokenFileHalts() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = home.appendingPathComponent(".config/super-keys/bindings.toml")
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    try "[[bind\n".write(to: file, atomically: true, encoding: .utf8)
    let loaded = BindingsFile.load(argument: nil, currentDirectory: "/tmp", homeDirectory: home.path)
    guard case .halt(let message, let code) = loaded else {
        Issue.record("expected a broken file to stop")
        return
    }
    #expect(code == 2)
    #expect(message.contains(file.path))
    #expect(message.contains("Line"))
}

private func catalogPath() throws -> String {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for _ in 0..<6 {
        let candidate = url.appendingPathComponent("bindings.toml")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.path
        }
        url.deleteLastPathComponent()
    }
    Issue.record("bindings.toml not found from \(#filePath)")
    throw BindingsError("bindings.toml not found")
}

private func bind(action: String, command: String = "a", scope: [String] = ["macos"]) -> String {
    let scopeText = scope.map { "\"\($0)\"" }.joined(separator: ", ")
    return """
    browser = '/Applications/Brave Browser.app'

    [[bind]]
    id = "one"
    group = "launch"
    scope = [\(scopeText)]
    command = "\(command)"
    \(action)
    """
}

private func row(_ bind: Bind) -> String {
    let scopes = bind.scope.map(\.rawValue).sorted().joined(separator: ",")
    let mods = bind.modifiers.map(\.rawValue).joined(separator: ",")
    let modsField = mods.isEmpty ? "-" : mods
    return "\(bind.id) | \(bind.group.rawValue) | \(scopes) | \(bind.command) | \(modsField) | \(actionText(bind.action))"
}

private func actionText(_ action: Action) -> String {
    switch action {
    case .launch(let app): "launch \(app)"
    case .openURL(let url): "open-url \(url)"
    case .finderOpen(let app): "finder-open \(app)"
    case .finderNewFile: "finder-new-file"
    case .shell(let argv): "shell \(argv.joined(separator: " | "))"
    case .appleScript(let source): "applescript \(source)"
    case .openTrash: "open-trash"
    case .emptyTrash: "empty-trash"
    case .sleep: "sleep"
    case .toggleAppearance: "toggle-appearance"
    }
}

private let expectedRows = [
    "terminal | launch | macos,omarchy | return | command | launch /Applications/Ghostty.app",
    "browser | launch | macos,omarchy | return | command,shift | launch /Applications/Brave Browser.app",
    "ai-assistant | launch | macos,omarchy | a | command,shift | open-url https://grok.com",
    "email | launch | macos,omarchy | e | command,shift | launch /System/Applications/Mail.app",
    "finder | launch | macos,omarchy | f | command,shift | launch /System/Library/CoreServices/Finder.app",
    "obsidian | launch | macos,omarchy | o | command,shift | launch /Applications/Obsidian.app",
    "music | launch | macos,omarchy | m | command,shift | launch /System/Applications/Music.app",
    "music-secondary | launch | macos,omarchy | m | command,shift,option | open-url https://music.youtube.com",
    "passwords | launch | macos,omarchy | slash | command,shift | launch /System/Applications/Passwords.app",
    "write | launch | macos,omarchy | w | command,shift | launch /Applications/Typora.app",
    "youtube | launch | macos,omarchy | y | command,shift | open-url https://www.youtube.com/feed/subscriptions",
    "develop | launch | macos,omarchy | d | command,shift | launch /Applications/Zed.app",
    "git-client | launch | macos,omarchy | g | command,shift | launch /Applications/Fork.app",
    "talk | launch | macos,omarchy | t | command,shift | open-url https://web.telegram.org",
    "develop-secondary | launch | macos | d | command,shift,option | shell /bin/zsh | -c | open \"${$(xcode-select -p)%/Contents/Developer}\"",
    "system-settings | launch | macos | s | command,shift | launch /System/Applications/System Settings.app",
    "talk-secondary | launch | macos | t | command,shift,option | launch /Applications/WhatsApp.app",
    "trash | launch | macos | delete | command,shift | open-trash",
    "finder-terminal | finder | macos | return | command,control | finder-open /Applications/Ghostty.app",
    "finder-develop | finder | macos | d | command,shift,control | finder-open /Applications/Zed.app",
    "finder-new-file | finder | macos | f | command,shift,control | finder-new-file",
    "finder-write | finder | macos | w | command,shift,control | finder-open /Applications/Typora.app",
    "appearance | system | macos | d | command,control | toggle-appearance",
    "sleep | system | macos | s | command,control | sleep",
    "empty-trash | system | macos | delete | command,control | empty-trash",
]
