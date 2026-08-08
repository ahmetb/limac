import Foundation

/// One lifecycle event from `limactl watch --json`, reduced to the fields
/// Limac acts on. Events whose payload is something else entirely (port
/// forwards, vsock, cloud-init) decode with all flags false — they still
/// mark activity during a boot.
struct LimaEvent {
    let instance: String
    let running: Bool
    let degraded: Bool
    let exiting: Bool
}

/// Keeps `limactl watch --json --history` running and delivers each decoded
/// event (on the main queue). `--history` replays the current boot's events
/// on every (re)spawn — `limactl start` truncates the event log per boot, so
/// the replay is bounded — letting readiness state survive app launches and
/// watcher restarts. Undecodable output is delivered as nil: still a reason
/// to re-read `limactl list`, just not a lifecycle fact.
final class LimaWatcher {
    private let limactlPath: String
    private let onEvent: (LimaEvent?) -> Void
    private var process: Process?
    private var stopped = false

    init(limactlPath: String, onEvent: @escaping (LimaEvent?) -> Void) {
        self.limactlPath = limactlPath
        self.onEvent = onEvent
    }

    /// Whether the watch child is currently running. Readiness gating in the
    /// UI switches off while this is false, so a Lima without a working
    /// `watch` subcommand degrades to plain list statuses.
    var isAlive: Bool { process?.isRunning ?? false }

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
        process.arguments = ["watch", "--json", "--history"]
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        // The handler runs serially per file handle, so the line buffer needs
        // no locking; it's per-spawn state and dies with the pipe.
        var buffer = Data()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            buffer.append(data)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer.prefix(upTo: newline)
                buffer = Data(buffer.suffix(from: newline + 1))
                let event = Self.parse(line)
                DispatchQueue.main.async { self?.onEvent(event) }
            }
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

    private static func parse(_ line: Data) -> LimaEvent? {
        struct WatchLine: Decodable {
            struct Payload: Decodable {
                struct Status: Decodable {
                    let running: Bool?
                    let degraded: Bool?
                    let exiting: Bool?
                }
                let status: Status?
            }
            let instance: String
            let event: Payload?
        }
        guard let decoded = try? JSONDecoder().decode(WatchLine.self, from: line) else {
            return nil
        }
        let status = decoded.event?.status
        return LimaEvent(instance: decoded.instance,
                         running: status?.running ?? false,
                         degraded: status?.degraded ?? false,
                         exiting: status?.exiting ?? false)
    }
}
