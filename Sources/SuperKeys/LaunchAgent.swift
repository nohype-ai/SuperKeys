import Darwin
import Foundation

enum LaunchAgent {
    static let label = "ai.nohype.super-keys"

    static var domain: String { "gui/\(getuid())" }

    static func startedByLaunchd() -> Bool {
        let parent = getppid()
        if parent == 1 { return true }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = buffer.withUnsafeMutableBufferPointer { pointer -> Int32 in
            proc_pidpath(parent, pointer.baseAddress, UInt32(pointer.count))
        }
        guard length > 0 else { return false }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self).hasSuffix("/launchd")
    }

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents")
            .appending(path: "\(label).plist")
    }

    /// Write the login agent for this executable and start it. The caller exits;
    /// launchd starts the process that actually registers hotkeys.
    static func installAndStart(bindingsPath: String) {
        let executable = executablePath()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let agents = home.appending(path: "Library/LaunchAgents")
        let logs = home.appending(path: "Library/Logs")
        do {
            try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        } catch {
            fputs("super-keys: could not create LaunchAgent directories: \(error)\n", stderr)
            exit(1)
        }

        let log = logs.appending(path: "super-keys.log").path
        writePlist(at: plistURL, executable: executable, bindingsPath: bindingsPath, log: log)

        unload()
        killOthers()
        guard launchctl(["bootstrap", domain, plistURL.path]) == 0 else {
            fputs("super-keys: launchctl bootstrap failed\n", stderr)
            exit(1)
        }
        launchctl(["enable", "\(domain)/\(label)"])
        print("super-keys is running under launchd (\(domain)/\(label))")
    }

    static func stop() {
        unload()
        killOthers()
        print("super-keys stopped")
    }

    /// Bootout the job and delete its plist so login does not start it again.
    /// The plist goes first: bootout of this process can kill it immediately.
    static func unregister() {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try? FileManager.default.removeItem(at: plistURL)
        }
        killOthers()
        unload()
    }

    static func unload() {
        launchctl(["bootout", "\(domain)/\(label)"], quiet: true)
    }

    static func killOthers() {
        let me = ProcessInfo.processInfo.processIdentifier
        for pid in superKeysPIDs() where pid != me {
            Darwin.kill(pid, SIGTERM)
        }
    }

    /// Absolute path suitable for launchd. Keeps a symlink such as
    /// /opt/homebrew/bin/super-keys so a brew upgrade does not strand the plist.
    static func executablePath() -> String {
        let arg0 = CommandLine.arguments[0]
        if arg0.hasPrefix("/") { return arg0 }
        if arg0.contains("/") {
            return URL(fileURLWithPath: arg0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
        }
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in pathEnv.split(separator: ":") where !directory.isEmpty {
            let candidate = "\(directory)/\(arg0)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return arg0
    }

    private static func writePlist(at url: URL, executable: String, bindingsPath: String, log: String) {
        let object: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable, "--agent", bindingsPath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
            "StandardOutPath": log,
            "StandardErrorPath": log,
        ]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            fputs("super-keys: could not write \(url.path): \(error)\n", stderr)
            exit(1)
        }
    }

    private static func superKeysPIDs() -> [pid_t] {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "super-keys"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return []
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.split(separator: "\n").compactMap { pid_t($0) }
    }

    @discardableResult
    private static func launchctl(_ arguments: [String], quiet: Bool = false) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        if quiet {
            process.standardError = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
        }
        do {
            try process.run()
        } catch {
            return 1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
