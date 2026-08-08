import Foundation

/// Keeps `limactl watch --json` running and fires `onEvent` (on the main
/// queue) whenever anything happens. The event content is irrelevant: every
/// event just triggers a re-read of `limactl list --json`, so the panel and
/// icon stay fresh without a polling loop — including for VMs started or
/// stopped from a terminal.
final class LimaWatcher {
    private let limactlPath: String
    private let onEvent: () -> Void
    private var process: Process?
    private var stopped = false

    init(limactlPath: String, onEvent: @escaping () -> Void) {
        self.limactlPath = limactlPath
        self.onEvent = onEvent
    }

    func start() {
        spawn()
    }

    func stop() {
        stopped = true
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
    }

    private func spawn() {
        guard !stopped else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: limactlPath)
        process.arguments = ["watch", "--json"]
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard !handle.availableData.isEmpty else { return }
            DispatchQueue.main.async { self?.onEvent() }
        }

        // If watch dies (lima upgraded, hostagent hiccup), come back up.
        process.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.spawn()
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.spawn()
            }
        }
    }
}
