import Foundation

struct CommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    var succeeded: Bool { exitCode == 0 }
}

/// Locating and shelling out to `limactl`. Every action Limac takes goes
/// through here — it links nothing from Lima and never bypasses the CLI.
enum Limactl {
    /// Homebrew locations, for when Limac is launched outside a login shell.
    private static let fallbackDirs = ["/opt/homebrew/bin", "/usr/local/bin"]

    static func resolvePath() -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var dirs = envPath.split(separator: ":").map(String.init)
        dirs.append(contentsOf: fallbackDirs)
        for dir in dirs {
            let candidate = (dir as NSString).appendingPathComponent("limactl")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Runs `limactl` asynchronously; the completion is invoked on the main queue.
    static func run(_ limactlPath: String, _ arguments: [String],
                    completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: limactlPath)
            process.arguments = arguments

            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err
            process.standardInput = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    completion(CommandResult(exitCode: -1, stdout: "",
                                             stderr: error.localizedDescription))
                }
                return
            }

            // Drain both pipes concurrently so a chatty stderr (limactl start
            // logs progress there) can't deadlock against a full pipe buffer.
            var outData = Data()
            var errData = Data()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                outData = out.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                errData = err.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.wait()
            process.waitUntilExit()

            let result = CommandResult(
                exitCode: process.terminationStatus,
                stdout: String(data: outData, encoding: .utf8) ?? "",
                stderr: String(data: errData, encoding: .utf8) ?? "")
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Parses "limactl version 2.2.0" → (2, 2). Returns nil when unparseable
    /// (dev builds); callers should treat nil as "don't gate".
    static func parseVersion(_ output: String) -> (major: Int, minor: Int)? {
        for word in output.split(whereSeparator: { $0.isWhitespace }) {
            let numbers = word.split(separator: ".").map { part in
                Int(part.prefix(while: \.isNumber))
            }
            if numbers.count >= 2, let major = numbers[0], let minor = numbers[1] {
                return (major, minor)
            }
        }
        return nil
    }
}
