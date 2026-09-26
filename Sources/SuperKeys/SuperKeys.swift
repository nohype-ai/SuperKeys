import AppKit
import HotKey

@main
@MainActor
struct SuperKeys {
    // MainActor-isolated so Swift 6 allows a process-lifetime [HotKey] without nonisolated(unsafe).
    // First access is from main(), after NSApplication.shared.
    static let hotKeys = createHotKeys()

    static func main() {
        // inspect logs via the file ~/Library/Logs/super-keys.log
        setlinebuf(stdout)
        setlinebuf(stderr)
        
        // get the app object
        print("Preparing application ...")
        let app = NSApplication.shared
        
        // no Dock, no menu bar
        app.setActivationPolicy(.prohibited)
        
        // run
        print("Waiting for key commands to process ...")
        app.run()
    }
    
    static func createHotKeys() -> [HotKey] {
        print("Registering key commands ...")
        return [
            // MARK: Launch Stuff - macOS + Omarchy (Omarchy Default)
            
            // Terminal
            HotKey(key: .return, modifiers: [.command]) {
                launch(app: "/Applications/Ghostty.app")
            },
            // Internet Browser
            HotKey(key: .return, modifiers: [.command, .shift]) {
                launch(app: browserPath)
            },
            // AI Assistant
            HotKey(key: .a, modifiers: [.command, .shift]) {
                open(website: "https://grok.com")
            },
            // Email
            HotKey(key: .e, modifiers: [.command, .shift]) {
                launch(app: "/System/Applications/Mail.app")
            },
            // Find(er) / File Manager
            HotKey(key: .f, modifiers: [.command, .shift]) {
                launch(app: "/System/Library/CoreServices/Finder.app")
            },
            // Organize / Obsidian
            HotKey(key: .o, modifiers: [.command, .shift]) {
                launch(app: "/Applications/Obsidian.app")
            },
            // Music
            HotKey(key: .m, modifiers: [.command, .shift]) {
                launch(app: "/System/Applications/Music.app")
            },
            // Music - Secondary
            HotKey(key: .m, modifiers: [.command, .shift, .option]) {
                open(website: "https://music.youtube.com")
            },
            // Password Manager
            HotKey(key: .slash, modifiers: [.command, .shift]) {
                launch(app: "/System/Applications/Passwords.app")
            },
            // Write
            HotKey(key: .w, modifiers: [.command, .shift]) {
                launch(app: "/Applications/Typora.app")
            },
            // YouTube
            HotKey(key: .y, modifiers: [.command, .shift]) {
                open(website: "https://www.youtube.com/feed/subscriptions")
            },
            
            // MARK: Launch Stuff - macOS + Omarchy (Omarchy Customized)
            
            // Develop
            HotKey(key: .d, modifiers: [.command, .shift]) {
                launch(app: "/Applications/Zed.app")
            },
            // Git Client
            HotKey(key: .g, modifiers: [.command, .shift]) {
                launch(app: "/Applications/Fork.app")
            },
            // Talk
            HotKey(key: .t, modifiers: [.command, .shift]) {
                open(website: "https://web.telegram.org")
            },
            
            // MARK: Launch Stuff - macOS Only
            
            // Develop - Secondary
            HotKey(key: .d, modifiers: [.command, .shift, .option]) {
                run("/bin/zsh", "-c", #"open "${$(xcode-select -p)%/Contents/Developer}""#)
            },
            // System Settings
            HotKey(key: .s, modifiers: [.command, .shift]) {
                launch(app: "/System/Applications/System Settings.app")
            },
            // Talk - Secondary
            HotKey(key: .t, modifiers: [.command, .shift, .option]) {
                launch(app: "/Applications/WhatsApp.app")
            },
            // Trash
            HotKey(key: .delete, modifiers: [.command, .shift]) {
                NSWorkspace.shared.open(
                    URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")
                )
            },
            
            // MARK: Do Stuff in Finder Folder - macOS Only
            
            // Terminal in folder
            HotKey(key: .return, modifiers: [.command, .control]) {
                openFinderFolder(in: "/Applications/Ghostty.app")
            },
            // Develop in folder
            HotKey(key: .d, modifiers: [.command, .shift, .control]) {
                openFinderFolder(in: "/Applications/Zed.app")
            },
            // Create new file in folder
            HotKey(key: .f, modifiers: [.command, .shift, .control]) {
                createNewFileInFinderFolder()
            },
            // Write in folder
            HotKey(key: .w, modifiers: [.command, .shift, .control]) {
                openFinderFolder(in: "/Applications/Typora.app")
            },
            
            // MARK: System Controls - macOS Only
            
            // Switch Dark/Day Mode
            HotKey(key: .d, modifiers: [.control, .command]) {
                _ = runAppleScript("""
                    tell application "System Events"
                        tell appearance preferences
                            set dark mode to not dark mode
                        end tell
                    end tell
                    """)
            },
            // Put System to Sleep
            HotKey(key: .s, modifiers: [.control, .command]) {
                run("/usr/bin/pmset", "sleepnow")
            },
            // Empty the Trash
            HotKey(key: .delete, modifiers: [.control, .command]) {
                _ = runAppleScript("tell application \"Finder\" to empty the trash")
            },
        ]
    }
    
    static func launch(app appPath: String) {
        print("Launching app " + appPath)
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: appPath),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
    
    static func open(website: String) {
        guard let websiteURL = URL(string: website) else {
            print("Can't make URL from " + website)
            return
        }
        
        print("Opening website " + website)
        NSWorkspace.shared.open(
            [websiteURL],
            withApplicationAt: browserURL,
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
    
    static func run(_ command: String, _ args: String...) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        try? process.run()
    }
    
    static let browserURL = URL(fileURLWithPath: browserPath)
    static let browserPath = "/Applications/Brave Browser.app"
}
