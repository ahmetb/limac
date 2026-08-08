import AppKit

/// Terminal apps Limac knows how to open a shell in.
enum TerminalApp: String, CaseIterable {
    case terminal = "Terminal"
    case iterm2 = "iTerm2"
    case ghostty = "Ghostty"

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .ghostty: return "com.mitchellh.ghostty"
        }
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}

/// App-level conveniences that touch no Lima data — the entire settings
/// surface Limac keeps for itself (see docs/design.md).
enum Preferences {
    // An explicit suite because a bare `swift run` executable has no bundle
    // identifier for UserDefaults.standard to key off.
    private static let defaults = UserDefaults(suiteName: "dev.limac") ?? .standard
    private static let terminalKey = "terminalApp"

    static var terminalApp: TerminalApp {
        get {
            defaults.string(forKey: terminalKey)
                .flatMap(TerminalApp.init(rawValue:)) ?? .terminal
        }
        set { defaults.set(newValue.rawValue, forKey: terminalKey) }
    }
}
