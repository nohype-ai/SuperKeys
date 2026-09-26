import Foundation

/// The bindings file SuperKeys reads, and what to do when it cannot be applied.
public enum BindingsFile {
    /// Written when `~/.config/super-keys/bindings.toml` does not exist yet.
    public static let emptyTemplate = """
    # SuperKeys bindings. List every modifier you want, including command.
    # Add [[bind]] entries, then run `super-keys` again.
    # Shortcuts stay off until this file contains a macos bind.

    """

    public static func defaultPath(homeDirectory: String) -> String {
        URL(fileURLWithPath: homeDirectory, isDirectory: true)
            .appendingPathComponent(".config/super-keys/bindings.toml")
            .path
    }

    /// An explicit path wins. Otherwise `~/.config/super-keys/bindings.toml`.
    public static func resolve(argument: String?, currentDirectory: String, homeDirectory: String) -> String {
        if let argument {
            return absolute(argument, currentDirectory: currentDirectory)
        }
        return defaultPath(homeDirectory: homeDirectory)
    }

    public static func absolute(_ path: String, currentDirectory: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardized.path
        }
        return URL(fileURLWithPath: currentDirectory)
            .appendingPathComponent(path)
            .standardized
            .path
    }

    /// Load the file that should be in effect. Creates the default file when it is absent.
    /// Does not create a missing explicit path.
    public static func load(argument: String?, currentDirectory: String, homeDirectory: String) -> BindingsLoad {
        let path = resolve(argument: argument, currentDirectory: currentDirectory, homeDirectory: homeDirectory)
        var created = false
        if argument == nil, !isRegularFile(path) {
            do {
                try writeEmpty(at: path)
                created = true
            } catch {
                return .halt(
                    message: "super-keys: could not create \(path): \(error.localizedDescription)\n",
                    exitCode: 2
                )
            }
        }
        guard isRegularFile(path) else {
            return .halt(message: "super-keys: bindings file not found: \(path)\n", exitCode: 2)
        }
        let bindings: Bindings
        do {
            bindings = try Bindings.load(contentsOf: path)
        } catch {
            return .halt(message: "super-keys: \(path): \(error)\n", exitCode: 2)
        }
        if bindings.macosBinds.isEmpty {
            let createdLine = created ? "super-keys: created \(path)\n" : ""
            return .halt(
                message: "\(createdLine)super-keys: no macos bindings in \(path)\n",
                exitCode: 0
            )
        }
        return .ready(bindings, path: path)
    }

    private static func writeEmpty(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try emptyTemplate.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func isRegularFile(_ path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }
}

public enum BindingsLoad: Equatable {
    case ready(Bindings, path: String)
    case halt(message: String, exitCode: Int32)
}
