import AppKit

/// Opens commands in the user's preferred terminal.
enum TerminalLauncher {
    static func openShell(limactlPath: String, instanceName: String) {
        // env is interposed because Ghostty wraps exec commands in
        // `login(1)`, which rewrites argv[0] to the bare basename; limactl
        // locates its share/lima via argv[0] and warns when that bare name
        // isn't on the GUI PATH. env re-execs with the absolute path intact.
        launch(shellCommand: "\(shellQuote(limactlPath)) shell \(shellQuote(instanceName))",
               execArgv: ["/usr/bin/env", limactlPath, "shell", instanceName])
    }

    /// Opens a host shell aimed at a Kubernetes instance: KUBECONFIG is
    /// exported so kubectl and friends target the cluster, and
    /// `kubectl get nodes` runs first so the window shows right away
    /// whether the connection works.
    static func openKubectl(kubeconfigPath: String) {
        let command = "export KUBECONFIG=\(shellQuote(kubeconfigPath)); kubectl get nodes"
        // The exec-style terminals below run the argv without a user shell
        // around it, so wrap in a login shell (kubectl usually lives in
        // directories GUI apps don't have on PATH) and leave an interactive
        // shell behind, which inherits the exported KUBECONFIG.
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        launch(shellCommand: command,
               execArgv: [shell, "-l", "-c", "\(command); exec \(shellQuote(shell)) -i"])
    }

    /// `shellCommand` is typed into the scriptable terminals' new window;
    /// `execArgv` is execed directly by the rest — no shell quoting involved.
    private static func launch(shellCommand: String, execArgv: [String]) {
        switch Preferences.terminalApp {
        case .terminal:
            runAppleScript("""
            tell application "Terminal"
                activate
                do script "\(appleScriptEscape(shellCommand))"
            end tell
            """)
        case .iterm2:
            runAppleScript("""
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(appleScriptEscape(shellCommand))"
                end tell
            end tell
            """)
        case .ghostty:
            openApp("Ghostty", args: ["-e"] + execArgv)
        case .wezterm:
            openApp("WezTerm", args: ["start", "--"] + execArgv)
        case .alacritty:
            openApp("Alacritty", args: ["-e"] + execArgv)
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
