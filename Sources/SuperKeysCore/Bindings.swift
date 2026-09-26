import Foundation
import TOMLDecoder

public struct Bindings: Equatable, Sendable {
    /// Required only when a bind uses `open-url`.
    public var browser: String?
    public var binds: [Bind]

    public var macosBinds: [Bind] {
        binds.filter { $0.scope.contains(.macos) }
    }

    public static func load(contentsOf path: String) throws -> Bindings {
        let text: String
        do {
            text = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw BindingsError("could not read \(path): \(error.localizedDescription)")
        }
        return try load(text)
    }

    public static func load(_ text: String) throws -> Bindings {
        let table: TOMLTable
        do {
            table = try TOMLTable(source: text)
        } catch {
            throw BindingsError(describe(error))
        }
        return try parse(table)
    }
}

public struct Bind: Equatable, Sendable {
    public var id: String
    public var group: Group
    public var scope: Set<Scope>
    public var command: String
    public var modifiers: [Modifier]
    public var action: Action
}

public enum Group: String, Equatable, Sendable {
    case launch, finder, system
}

public enum Scope: String, Equatable, Sendable, Hashable {
    case macos, omarchy
}

public enum Modifier: String, Equatable, Sendable, Hashable {
    case command, shift, option, control
}

public enum Action: Equatable, Sendable {
    case launch(app: String)
    case openURL(String)
    case finderOpen(app: String)
    case finderNewFile
    case shell(argv: [String])
    case appleScript(String)
    case openTrash
    case emptyTrash
    case sleep
    case toggleAppearance
}

public struct BindingsError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

private let fileKeys: Set = ["browser", "bind"]
private let bindKeys: Set = [
    "id", "group", "scope", "command", "modifiers", "action",
    "app", "url", "argv", "source",
]
private let payloadKeys = ["app", "url", "argv", "source"]


private struct Shortcut: Hashable {
    var command: String
    var modifiers: Set<Modifier>
}

private func parse(_ table: TOMLTable) throws -> Bindings {
    var problems: [String] = []
    for key in table.keys.sorted() where !fileKeys.contains(key) {
        problems.append("unknown key '\(key)'")
    }

    let browser = readString(table, "browser", problems: &problems, label: "browser")
    if table.contains(key: "browser"), browser?.isEmpty == true {
        problems.append("browser is empty")
    }

    var binds: [Bind] = []
    var seenIDs = Set<String>()
    var seenShortcuts: [Shortcut: String] = [:]

    if table.contains(key: "bind") {
        let rows: TOMLArray
        do {
            rows = try table.array(forKey: "bind")
        } catch {
            throw BindingsError(describe(error))
        }
        for index in 0..<rows.count {
            let row: TOMLTable
            do {
                row = try rows.table(atIndex: index)
            } catch {
                problems.append("bind \(index + 1): \(describe(error))")
                continue
            }
            guard let bind = parseBind(row, index: index, problems: &problems) else { continue }
            if seenIDs.contains(bind.id) {
                problems.append("duplicate id '\(bind.id)'")
            }
            seenIDs.insert(bind.id)
            let shortcut = Shortcut(command: bind.command, modifiers: Set(bind.modifiers))
            if let previous = seenShortcuts[shortcut] {
                problems.append("duplicate shortcut \(shortcutText(bind)) (\(previous) and \(bind.id))")
            } else {
                seenShortcuts[shortcut] = bind.id
            }
            binds.append(bind)
        }
    }

    let opensURL = binds.contains { if case .openURL = $0.action { true } else { false } }
    if opensURL, browser == nil || browser?.isEmpty == true {
        problems.append("open-url requires browser")
    }

    if !problems.isEmpty {
        throw BindingsError(problems.joined(separator: "\n"))
    }
    return Bindings(browser: browser, binds: binds)
}

private func parseBind(_ table: TOMLTable, index: Int, problems: inout [String]) -> Bind? {
    var row: [String] = []
    let id = readString(table, "id", problems: &row, label: "bind \(index + 1)")
    let label = (id?.isEmpty == false) ? "bind \(id!)" : "bind \(index + 1)"

    for key in table.keys.sorted() where !bindKeys.contains(key) {
        row.append("\(label): unknown key '\(key)'")
    }
    if !table.contains(key: "id") {
        row.append("\(label): missing id")
    } else if id?.isEmpty == true {
        row.append("\(label): id is empty")
    }

    let group = readGroup(table, label: label, problems: &row)
    let scope = readScope(table, label: label, problems: &row)
    let command = readCommand(table, label: label, problems: &row)
    let modifiers = readModifiers(table, label: label, problems: &row)
    let action = readAction(table, label: label, problems: &row)

    problems.append(contentsOf: row)
    guard row.isEmpty, let id, !id.isEmpty, let group, let scope, let command, let modifiers, let action else {
        return nil
    }
    return Bind(id: id, group: group, scope: scope, command: command, modifiers: modifiers, action: action)
}

private func readGroup(_ table: TOMLTable, label: String, problems: inout [String]) -> Group? {
    guard table.contains(key: "group") else {
        problems.append("\(label): missing group")
        return nil
    }
    guard let raw = readString(table, "group", problems: &problems, label: label) else { return nil }
    guard let group = Group(rawValue: raw) else {
        problems.append("\(label): unknown group '\(raw)'")
        return nil
    }
    return group
}

private func readScope(_ table: TOMLTable, label: String, problems: inout [String]) -> Set<Scope>? {
    guard table.contains(key: "scope") else {
        problems.append("\(label): missing scope")
        return nil
    }
    guard let names = readStrings(table, "scope", problems: &problems, label: label) else { return nil }
    if names.isEmpty {
        problems.append("\(label): scope is empty")
        return nil
    }
    var scope = Set<Scope>()
    var ok = true
    for name in names {
        guard scope.first(where: { $0.rawValue == name }) == nil else {
            problems.append("\(label): duplicate scope '\(name)'")
            ok = false
            continue
        }
        guard let value = Scope(rawValue: name) else {
            problems.append("\(label): unknown scope '\(name)'")
            ok = false
            continue
        }
        scope.insert(value)
    }
    return ok ? scope : nil
}

private func readCommand(_ table: TOMLTable, label: String, problems: inout [String]) -> String? {
    guard table.contains(key: "command") else {
        problems.append("\(label): missing command")
        return nil
    }
    guard let raw = readString(table, "command", problems: &problems, label: label) else { return nil }
    guard let name = KeyNames.canonical(raw) else {
        problems.append("\(label): unknown key '\(raw)'")
        return nil
    }
    return name
}

private func readModifiers(_ table: TOMLTable, label: String, problems: inout [String]) -> [Modifier]? {
    guard table.contains(key: "modifiers") else { return [] }
    guard let names = readStrings(table, "modifiers", problems: &problems, label: label) else { return nil }
    var modifiers: [Modifier] = []
    var ok = true
    for name in names {
        guard let modifier = Modifier(rawValue: name) else {
            problems.append("\(label): unknown modifier '\(name)'")
            ok = false
            continue
        }
        if modifiers.contains(modifier) {
            problems.append("\(label): duplicate modifier '\(name)'")
            ok = false
            continue
        }
        modifiers.append(modifier)
    }
    guard ok else { return nil }
    return modifiers.sorted { rank($0) < rank($1) }
}

private func readAction(_ table: TOMLTable, label: String, problems: inout [String]) -> Action? {
    guard table.contains(key: "action") else {
        problems.append("\(label): missing action")
        return nil
    }
    guard let name = readString(table, "action", problems: &problems, label: label) else { return nil }

    let allowed: Set<String>
    switch name {
    case "launch", "finder-open": allowed = ["app"]
    case "open-url": allowed = ["url"]
    case "shell": allowed = ["argv"]
    case "applescript": allowed = ["source"]
    case "finder-new-file", "open-trash", "empty-trash", "sleep", "toggle-appearance": allowed = []
    default:
        problems.append("\(label): unknown action '\(name)'")
        return nil
    }

    var rejected = false
    for key in payloadKeys where table.contains(key: key) && !allowed.contains(key) {
        problems.append("\(label): \(name) does not take \(key)")
        rejected = true
    }

    let action: Action?
    switch name {
    case "launch":
        action = readPayload(table, "app", label: label, problems: &problems).map { .launch(app: $0) }
    case "finder-open":
        action = readPayload(table, "app", label: label, problems: &problems).map { .finderOpen(app: $0) }
    case "open-url":
        guard let url = readPayload(table, "url", label: label, problems: &problems) else { return nil }
        guard URL(string: url)?.scheme != nil else {
            problems.append("\(label): url is not a URL")
            return nil
        }
        action = .openURL(url)
    case "shell":
        guard table.contains(key: "argv") else {
            problems.append("\(label): missing argv")
            return nil
        }
        guard let argv = readStrings(table, "argv", problems: &problems, label: label) else { return nil }
        if argv.isEmpty || argv.contains(where: \.isEmpty) {
            problems.append("\(label): argv must be a non-empty list of strings")
            return nil
        }
        action = .shell(argv: argv)
    case "applescript":
        action = readPayload(table, "source", label: label, problems: &problems).map { .appleScript($0) }
    case "finder-new-file": action = .finderNewFile
    case "open-trash": action = .openTrash
    case "empty-trash": action = .emptyTrash
    case "sleep": action = .sleep
    case "toggle-appearance": action = .toggleAppearance
    default: action = nil
    }
    return rejected ? nil : action
}

private func readPayload(_ table: TOMLTable, _ key: String, label: String, problems: inout [String]) -> String? {
    guard table.contains(key: key) else {
        problems.append("\(label): missing \(key)")
        return nil
    }
    guard let value = readString(table, key, problems: &problems, label: label) else { return nil }
    if value.isEmpty {
        problems.append("\(label): \(key) is empty")
        return nil
    }
    return value
}

private func readString(_ table: TOMLTable, _ key: String, problems: inout [String], label: String) -> String? {
    guard table.contains(key: key) else { return nil }
    do {
        return try table.string(forKey: key)
    } catch {
        problems.append("\(label): \(describe(error))")
        return nil
    }
}

private func readStrings(_ table: TOMLTable, _ key: String, problems: inout [String], label: String) -> [String]? {
    do {
        let array = try table.array(forKey: key)
        var values: [String] = []
        for index in 0..<array.count {
            values.append(try array.string(atIndex: index))
        }
        return values
    } catch {
        problems.append("\(label): \(describe(error))")
        return nil
    }
}

private func rank(_ modifier: Modifier) -> Int {
    switch modifier {
    case .command: 0
    case .shift: 1
    case .option: 2
    case .control: 3
    }
}

private func shortcutText(_ bind: Bind) -> String {
    let mods = bind.modifiers.map(\.rawValue).joined(separator: "+")
    return mods.isEmpty ? bind.command : "\(bind.command)+\(mods)"
}

private func describe(_ error: Error) -> String {
    if let bindings = error as? BindingsError { return bindings.message }
    if let toml = error as? TOMLError { return toml.description }
    return String(describing: error)
}
