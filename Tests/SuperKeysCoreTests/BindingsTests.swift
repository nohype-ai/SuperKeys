import Foundation
import Testing
@testable import SuperKeysCore

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

