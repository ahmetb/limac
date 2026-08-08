import Foundation

/// One instance as reported by `limactl list --json` (one JSON object per line).
/// Fields mirror limactl's output verbatim; Limac adds nothing.
struct Instance: Decodable {
    let name: String
    let status: String
    let cpus: Int?
    let memory: Int64?
    let disk: Int64?
    let sshConfigFile: String?
    let protected: Bool?
    let message: String?

    var isRunning: Bool { status == "Running" }
    var isProtected: Bool { protected ?? false }

    /// "Running · 8 CPU · 12 GB · 100 GB" — configured shape, not live usage
    /// (limactl doesn't provide usage).
    var statusLine: String {
        var parts = [status.isEmpty ? "Unknown" : status]
        if let cpus { parts.append("\(cpus) CPU") }
        if let memory { parts.append(Self.formatBytes(memory)) }
        if let disk { parts.append(Self.formatBytes(disk)) }
        return parts.joined(separator: " · ")
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Parses the JSON Lines output of `limactl list --json`.
    static func parseList(_ output: String) -> [Instance] {
        let decoder = JSONDecoder()
        return output
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(Instance.self, from: data)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
