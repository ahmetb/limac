import AppKit

/// Opens `limactl shell <name>` in the user's preferred terminal.
enum TerminalLauncher {
    static func openShell(limactlPath: String, instanceName: String) {
        let command = "\(shellQuote(limactlPath)) shell \(shellQuote(instanceName))"
        switch Preferences.terminalApp {
        case .terminal:
            runAppleScript("""
            tell application "Terminal"
                activate
                do script "\(appleScriptEscape(command))"
            end tell
            """)
        case .iterm2:
            runAppleScript("""
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(appleScriptEscape(command))"
                end tell
            end tell
            """)
        // The remaining terminals have no scripting interface but take the
        // command to run as process arguments, execed directly — no shell
        // quoting involved.
        case .ghostty:
            openApp("Ghostty", args: ["-e", limactlPath, "shell", instanceName])
        case .wezterm:
            openApp("WezTerm", args: ["start", "--", limactlPath, "shell", instanceName])
        case .alacritty:
            openApp("Alacritty", args: ["-e", limactlPath, "shell", instanceName])
        }
    }

    private static func openApp(_ appName: String, args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", appName, "--args"] + args
        try? process.run()
    }

    private static func runAppleScript(_ source: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        try? process.run()
    }

    private static func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
