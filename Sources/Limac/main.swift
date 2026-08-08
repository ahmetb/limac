import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only: no Dock icon, no main window. This also works when run as a
// bare executable via `swift run` (no app bundle / Info.plist needed).
app.setActivationPolicy(.accessory)

// Route Ctrl-C / kill through NSApp.terminate so applicationWillTerminate
// runs and the `limactl watch` child isn't orphaned.
let signalSources = [SIGINT, SIGTERM].map { sig in
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { app.terminate(nil) }
    source.resume()
    return source
}

app.run()
