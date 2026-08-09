import AppKit

/// Terminal apps Limac knows how to open a shell in, in detection-priority
/// order: someone who installed a third-party terminal almost certainly
/// prefers it over Terminal.app, so Terminal is the last resort.
///
/// Warp is deliberately absent: it has no CLI flag or URI parameter to open
/// a tab running a given command (its warp:// scheme only opens paths), so
/// Limac can't open a shell in it.
enum TerminalApp: String, CaseIterable {
    case ghostty = "Ghostty"
    case iterm2 = "iTerm2"
    case wezterm = "WezTerm"
    case alacritty = "Alacritty"
    case terminal = "Terminal"

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .ghostty: return "com.mitchellh.ghostty"
        case .wezterm: return "com.github.wez.wezterm"
        case .alacritty: return "org.alacritty"
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
    // identifier for UserDefaults.standard to key off. In the packaged app
    // the bundle identifier IS dev.limac, so this initializer returns nil
    // (suite == own bundle id is disallowed) and the .standard fallback
    // lands on the same ~/Library/Preferences/dev.limac.plist — both run
    // modes share one settings store. Don't "fix" the fallback.
    private static let defaults = UserDefaults(suiteName: "dev.limac") ?? .standard
    private static let terminalKey = "terminalApp"

    static var terminalApp: TerminalApp {
        get {
            // An explicit choice wins; otherwise guess from what's installed.
            defaults.string(forKey: terminalKey)
                .flatMap(TerminalApp.init(rawValue:))
                ?? TerminalApp.allCases.first(where: \.isInstalled)
                ?? .terminal
        }
        set { defaults.set(newValue.rawValue, forKey: terminalKey) }
    }
}
