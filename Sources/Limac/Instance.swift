import Foundation

/// One instance as reported by `limactl list --json` (one JSON object per line).
/// Fields mirror limactl's output verbatim; Limac adds nothing.
struct Instance: Decodable {
    let name: String
    let status: String
    let cpus: Int?
    let memory: Int64?
    let disk: Int64?
    let dir: String?
    let sshConfigFile: String?
    let protected: Bool?
    let message: String?
    let config: Config?

    /// The slice of the embedded instance config Limac reads. All of Lima's
    /// Kubernetes templates (k0s, k3s, k8s, rke2, u7s) export the cluster's
    /// admin kubeconfig to the host through a copyToHost rule.
    struct Config: Decodable {
        let copyToHost: [CopyRule]?
        struct CopyRule: Decodable {
            let host: String?
        }
    }

    var isRunning: Bool { status == "Running" }
    var isProtected: Bool { protected ?? false }

    /// Host path of the cluster's kubeconfig, or nil for non-Kubernetes
    /// instances. Lima keeps no record of the source template, so the
    /// kubeconfig copy rule — shared by every Kubernetes template — is the
    /// detection signal.
    var kubeconfigPath: String? {
        config?.copyToHost?.compactMap(\.host)
            .first { $0.hasSuffix("/copied-from-guest/kubeconfig.yaml") }
    }

    var isKubernetes: Bool { kubeconfigPath != nil }

    /// The kubeconfig is copied to the host only once the cluster's API
    /// server is up — after the list already says Running — and is deleted
    /// on stop, so the file's existence is the "kubectl works now" signal.
    var kubeconfigReady: Bool {
        guard isRunning, let path = kubeconfigPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

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
