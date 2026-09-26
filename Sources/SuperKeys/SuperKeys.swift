import AppKit
import HotKey
import SuperKeysCore

@main
@MainActor
struct SuperKeys {
    static let usage = """
    usage: super-keys [bindings.toml]
           super-keys stop
           super-keys --foreground [bindings.toml]
    """

    static func main() {
        // A launchd start must not re-register: bootout would kill this process
        // before the new job is up. The plist passes --agent; ppid 1 covers an
        // older plist that only stored the binary path.
        switch command(from: Array(CommandLine.arguments.dropFirst())) {
        case .install(let path) where path == nil && LaunchAgent.startedByLaunchd():
            startAgent(argument: nil)
        case .install(let path):
            switch prepare(argument: path) {
            case .ready(_, path: let bindingsPath):
                LaunchAgent.installAndStart(bindingsPath: bindingsPath)
            case .halt(let message, let code):
                stopBecause(message, code)
            }
        case .stop:
            LaunchAgent.stop()
        case .foreground(let path):
            switch prepare(argument: path) {
            case .ready(let bindings, path: let bindingsPath):
                LaunchAgent.unload()
                LaunchAgent.killOthers()
                runLoop(bindings: bindings, path: bindingsPath)
            case .halt(let message, let code):
                stopBecause(message, code)
            }
        case .agent(let path):
            startAgent(argument: path)
        case .help:
            print(usage)
            print("Bindings: ~/.config/super-keys/bindings.toml")
            print("Edit that file, then run super-keys again. Log: ~/Library/Logs/super-keys.log")
        case .invalid:
            fputs(usage + "\n", stderr)
            exit(2)
        }
    }

    /// launchd KeepAlive restarts a non-zero exit, so the agent always exits 0 after unloading.
    private static func startAgent(argument: String?) {
        switch prepare(argument: argument) {
        case .ready(let bindings, path: let path):
            runLoop(bindings: bindings, path: path)
        case .halt(let message, _):
            stopBecause(message, 0)
        }
    }

    private static func prepare(argument: String?) -> BindingsLoad {
        let loaded = BindingsFile.load(
            argument: argument,
            currentDirectory: FileManager.default.currentDirectoryPath,
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )
        guard case .ready(let bindings, let path) = loaded else { return loaded }
        for bind in bindings.macosBinds {
            guard Key(string: bind.command) != nil else {
                return .halt(
                    message: "super-keys: \(path): HotKey rejected '\(bind.command)' (\(bind.id))\n",
                    exitCode: 2
                )
            }
        }
        return loaded
    }

    /// Unload the login agent, then exit. Nothing stays registered.
    private static func stopBecause(_ message: String, _ code: Int32) -> Never {
        fputs(message, stderr)
        LaunchAgent.unregister()
        fputs("super-keys stopped\n", stderr)
        exit(code)
    }

    static func runLoop(bindings: Bindings, path: String) {
        // inspect logs via the file ~/Library/Logs/super-keys.log
        setlinebuf(stdout)
        setlinebuf(stderr)

        print("Preparing application ...")
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let hotKeys = makeHotKeys(bindings, path: path)

        print("Waiting for key commands to process ...")
        // HotKey's controller holds the key weakly. The array has to stay alive
        // for the whole run loop, or the shortcuts unregister themselves.
        withExtendedLifetime(hotKeys) {
            app.run()
        }
    }

    private static func makeHotKeys(_ bindings: Bindings, path: String) -> [HotKey] {
        let binds = bindings.macosBinds
        var keys: [Key] = []
        keys.reserveCapacity(binds.count)
        for bind in binds {
            guard let key = Key(string: bind.command) else {
                stopBecause("super-keys: \(path): HotKey rejected '\(bind.command)' (\(bind.id))\n", 0)
            }
            keys.append(key)
        }

        print("Registering \(binds.count) key commands from \(path)")
        return zip(binds, keys).map { bind, key in
            let action = bind.action
            let browser = bindings.browser
            return HotKey(key: key, modifiers: eventModifiers(bind.modifiers)) {
                perform(action, browser: browser)
            }
        }
    }

    private static func eventModifiers(_ modifiers: [Modifier]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.command)
            case .shift: flags.insert(.shift)
            case .option: flags.insert(.option)
            case .control: flags.insert(.control)
            }
        }
        return flags
    }

    private static func perform(_ action: Action, browser: String?) {
        switch action {
        case .launch(let app):
            launch(app: app)
        case .openURL(let website):
            guard let browser else {
                print("No browser configured")
                return
            }
            open(website: website, browser: browser)
        case .finderOpen(let app):
            openFinderFolder(in: app)
        case .finderNewFile:
            createNewFileInFinderFolder()
        case .shell(let argv):
            run(argv[0], Array(argv.dropFirst()))
        case .appleScript(let source):
            _ = runAppleScript(source)
        case .openTrash:
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash"))
        case .emptyTrash:
            _ = runAppleScript("tell application \"Finder\" to empty the trash")
        case .sleep:
            run("/usr/bin/pmset", ["sleepnow"])
        case .toggleAppearance:
            _ = runAppleScript("""
                tell application "System Events"
                    tell appearance preferences
                        set dark mode to not dark mode
                    end tell
                end tell
                """)
        }
    }

    static func launch(app appPath: String) {
        print("Launching app " + appPath)
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: appPath),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    static func open(website: String, browser: String) {
        guard let websiteURL = URL(string: website) else {
            print("Can't make URL from " + website)
            return
        }

        print("Opening website " + website)
        NSWorkspace.shared.open(
            [websiteURL],
            withApplicationAt: URL(fileURLWithPath: browser),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    static func openFinderFolder(in appPath: String) {
        guard let folder = finderFolder() else { return }

        print("Opening Finder folder in app " + appPath)
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: folder)],
            withApplicationAt: URL(fileURLWithPath: appPath),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    static func createNewFileInFinderFolder() {
        guard let folder = finderFolder() else { return }
        let folderURL = URL(fileURLWithPath: folder)
        var url = folderURL.appendingPathComponent("_new.md")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folderURL.appendingPathComponent("_new \(n).md")
            n += 1
        }

        print("Creating file in Finder folder: " + url.lastPathComponent)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func finderFolder() -> String? {
        guard var folder = runAppleScript("""
            tell application "Finder"
                if (count of Finder windows) is 0 then return
                POSIX path of (insertion location as alias)
            end tell
            """), !folder.isEmpty else { return nil }
        folder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        if folder.count > 1, folder.hasSuffix("/") { folder.removeLast() }
        return folder
    }

    static func runAppleScript(_ source: String) -> String? {
        NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
    }

    static func run(_ command: String, _ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        try? process.run()
    }
}

private enum Command {
    case install(String?)
    case stop
    case foreground(String?)
    case agent(String?)
    case help
    case invalid
}

private func command(from args: [String]) -> Command {
    if args.isEmpty { return .install(nil) }
    if args == ["stop"] { return .stop }
    if args == ["--help"] || args == ["-h"] { return .help }
    if args == ["--foreground"] { return .foreground(nil) }
    if args.count == 2, args[0] == "--foreground" { return .foreground(args[1]) }
    if args == ["--agent"] { return .agent(nil) }
    if args.count == 2, args[0] == "--agent" { return .agent(args[1]) }
    if args.count == 1, !args[0].hasPrefix("-") { return .install(args[0]) }
    return .invalid
}
