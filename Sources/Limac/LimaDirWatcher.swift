import Foundation

/// Filesystem-level freshness alongside `limactl watch`: kqueue sources on
/// ~/.lima and each instance directory. Starting and stopping churns pid and
/// socket files in there, and creating or deleting instances adds or removes
/// directories — any directory-entry change is a cue to re-read
/// `limactl list`. Push-based like the event stream, and catches state
/// changes even if the watch process is wedged.
final class LimaDirWatcher {
    private let onChange: () -> Void
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".lima")

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    /// Attaches sources for ~/.lima and every directory in it, dropping
    /// sources whose directories are gone. Call after each list refresh so
    /// newly created instances get covered.
    func sync() {
        var wanted: Set<String> = [root.path]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        for url in contents
        where (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            wanted.insert(url.path)
            // A Kubernetes instance's kubeconfig lands one level deeper, and
            // only once the cluster is actually up — well after the pid/sock
            // churn in the instance directory has settled. Watch it so the
            // kubectl menu action enables itself the moment the file appears.
            let copied = url.appendingPathComponent("copied-from-guest")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: copied.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                wanted.insert(copied.path)
            }
        }

        for (path, source) in sources where !wanted.contains(path) {
            source.cancel()
            sources[path] = nil
        }
        for path in wanted where sources[path] == nil {
            attach(path)
        }
    }

    func stop() {
        sources.values.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func attach(_ path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.onChange() }
        source.setCancelHandler { close(fd) }
        source.resume()
        sources[path] = source
    }
}
