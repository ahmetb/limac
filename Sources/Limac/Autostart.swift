import Foundation

/// Whether Lima will start an instance at login. The state is Lima's own
/// artifact — `limactl autostart enable` registers a LaunchAgent labeled
/// io.lima-vm.autostart.<instance> — so Limac only checks for that file and
/// always mutates it through the CLI, keeping the two in agreement.
enum Autostart {
    static func isEnabled(_ instanceName: String) -> Bool {
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/LaunchAgents/io.lima-vm.autostart.\(instanceName).plist")
        return FileManager.default.fileExists(atPath: plist.path)
    }
}
