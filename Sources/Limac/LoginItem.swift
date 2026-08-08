import Foundation

/// Launch-at-login for Limac itself, as a user LaunchAgent: SMAppService
/// needs an app bundle, and `swift run` produces a bare executable. The
/// agent points at the binary that is currently running.
///
/// Enabling only writes the plist — launchd picks it up at the next login.
/// (Bootstrapping it immediately would launch a second Limac right away.)
/// Disabling only removes it, so an instance launched by the agent isn't
/// killed out from under the user.
enum LoginItem {
    private static let label = "dev.limac"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static var executablePath: String? {
        Bundle.main.executablePath.map {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        }
    }

    static func enable() throws {
        guard let executablePath else { return }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                      format: .xml, options: 0)
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: plistURL)
    }

    static func disable() {
        try? FileManager.default.removeItem(at: plistURL)
    }
}
