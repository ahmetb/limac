import AppKit

/// The menu bar is the whole app: an NSStatusItem with a plain NSMenu.
/// State comes from `limactl list --json`; freshness from `limactl watch`.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    /// A limactl verb Limac itself launched and is still waiting on.
    private enum Operation {
        case start, stop, forceStop, restart, factoryReset, delete

        var label: String {
            switch self {
            case .start: "Starting…"
            case .stop: "Stopping…"
            case .forceStop: "Force stopping…"
            case .restart: "Restarting…"
            case .factoryReset: "Factory resetting…"
            case .delete: "Deleting…"
            }
        }

        func arguments(for name: String) -> [String] {
            switch self {
            case .start: ["start", name]
            case .stop: ["stop", name]
            case .forceStop: ["stop", "-f", name]
            case .restart: ["restart", name]
            case .factoryReset: ["factory-reset", name]
            case .delete: ["delete", name]
            }
        }

        /// True when Lima already reports the state this operation was
        /// driving toward — proof the VM got there even if our child process
        /// is still running (limactl stop has been seen not exiting after
        /// the VM reached Stopped). start settles when the list says Running
        /// *and* the boot's readiness phase is over: the list flips the
        /// moment the hostagent is up, while `limactl start` keeps probing
        /// requirements (ssh, boot scripts) until the hostagent's `running`
        /// event. restart passes *through* Running on its way down, so it
        /// can only settle when the process exits; delete settles when the
        /// instance disappears from the list.
        func isSettled(byStatus status: String, stillBooting: Bool) -> Bool {
            switch self {
            case .stop, .forceStop, .factoryReset: status == "Stopped"
            case .start: status == "Running" && !stillBooting
            case .restart, .delete: false
            }
        }
    }

    private var limactlPath: String?
    private var instances: [Instance] = []
    /// Instance name → operation in flight. Rows with an entry here show
    /// the operation's label and pause their transition verbs.
    private var busy: [String: Operation] = [:]
    /// Instances whose current boot has emitted watch events but not yet the
    /// hostagent's `running` event. `limactl list` flips to Running as soon
    /// as the hostagent is up — readiness (ssh, boot scripts, forwards) can
    /// lag by minutes — so a Running row still in here shows "Starting…".
    /// Empty whenever the watch stream is unavailable, which degrades rows
    /// back to plain list statuses.
    private var booting: Set<String> = []
    /// Instances whose current boot has emitted `running` (degraded or not).
    private var ready: Set<String> = []
    /// Subset of `ready` whose latest `running` event was degraded (VM up,
    /// but file sharing / port forwarding may not work).
    private var degraded: Set<String> = []
    /// False until the first `list --json` result lands; see
    /// `reconcileReadiness`.
    private var hasListedOnce = false
    /// Readiness gating only applies while the watch stream is up; without
    /// it, rows fall back to plain list statuses rather than waiting for
    /// events that will never come.
    private var watchAvailable: Bool { watcher?.isAlive ?? false }
    /// Set when the installed Lima is older than what Limac requires.
    private var unsupportedVersion: String?
    private var watcher: LimaWatcher?
    private var dirWatcher: LimaDirWatcher?
    private var refreshScheduled = false
    /// Cycles LimeIcon.frames while `busy` is non-empty; nil otherwise.
    private var iconAnimation: Timer?
    private var iconFrame = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        updateIcon()
        resolveLimactl()
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        dirWatcher?.stop()
    }

    // MARK: - State

    private func resolveLimactl() {
        guard limactlPath == nil else { return }
        guard let path = Limactl.resolvePath() else {
            rebuildMenu()
            return
        }
        limactlPath = path
        Limactl.run(path, ["--version"]) { [weak self] result in
            guard let self else { return }
            if let version = Limactl.parseVersion(result.stdout), version.major < 2 {
                self.unsupportedVersion = "\(version.major).\(version.minor)"
                self.rebuildMenu()
                return
            }
            self.watcher = LimaWatcher(limactlPath: path) { [weak self] event in
                self?.handle(event: event)
            }
            self.watcher?.start()
            self.dirWatcher = LimaDirWatcher { [weak self] in
                self?.scheduleRefresh()
            }
            self.dirWatcher?.sync()
            self.refresh()
        }
    }

    /// Folds one watch event into the readiness sets. Every event — decoded
    /// or not — also pokes the debounced list re-read, which is what redraws
    /// the menu.
    private func handle(event: LimaEvent?) {
        defer { scheduleRefresh() }
        guard let event else { return }
        if event.exiting {
            booting.remove(event.instance)
            ready.remove(event.instance)
            degraded.remove(event.instance)
        } else if event.running {
            booting.remove(event.instance)
            ready.insert(event.instance)
            // Sticky per boot: the hostagent evaluates requirements once, so
            // degraded can't recover until the next boot — and its routine
            // port-forward events repeat `running` without the flag.
            if event.degraded {
                degraded.insert(event.instance)
            }
        } else if !ready.contains(event.instance) {
            // Boot-phase activity (ssh port, early forwards) before the
            // `running` event. Once ready, runtime chatter must not drag an
            // instance back to "Starting…".
            booting.insert(event.instance)
        }
    }

    /// Debounces the bursts of events `limactl watch` emits during a state
    /// transition into a single `list --json` re-read.
    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }

    private func refresh() {
        guard let limactlPath else {
            resolveLimactl()  // picks Lima up the moment it's installed
            return
        }
        guard unsupportedVersion == nil else { return }
        Limactl.run(limactlPath, ["list", "--json"]) { [weak self] result in
            guard let self, result.succeeded else { return }
            let previous = self.instances
            self.instances = Instance.parseList(result.stdout)
            self.reconcileReadiness(previous: previous)
            self.reconcileBusy()
            self.rebuildMenu()
            self.updateIcon()
            self.dirWatcher?.sync()
        }
    }

    /// Readiness is per boot: an instance the list no longer reports as
    /// Running starts its next boot un-ready. The reverse transition —
    /// non-Running to Running — marks a boot as in progress immediately:
    /// the list flips the moment the hostagent is up, usually before its
    /// first event reaches us, and without this a fresh boot would briefly
    /// claim Running (and settle a pending start too early). The first list
    /// read skips that marking: instances already up when Limac launches get
    /// their readiness from the `--history` replay instead. `booting` is
    /// only trimmed to instances that still exist — boot events can precede
    /// the list flip, and quiet stretches between events are normal.
    private func reconcileReadiness(previous: [Instance]) {
        let running = Set(instances.filter(\.isRunning).map(\.name))
        ready.formIntersection(running)
        degraded.formIntersection(running)
        booting.formIntersection(instances.map(\.name))
        guard watchAvailable, hasListedOnce else {
            hasListedOnce = true
            return
        }
        let wasRunning = Set(previous.filter(\.isRunning).map(\.name))
        booting.formUnion(running.subtracting(wasRunning).subtracting(ready))
    }

    /// `limactl list` is the source of truth; a busy label is only Limac's
    /// promise that a command is still working. The moment the list shows
    /// the operation's target state (or the instance is gone), the label
    /// drops — the app must never contradict the CLI.
    private func reconcileBusy() {
        for (name, operation) in busy {
            guard let instance = instances.first(where: { $0.name == name }) else {
                busy[name] = nil
                continue
            }
            if operation.isSettled(byStatus: instance.status,
                                   stillBooting: watchAvailable && booting.contains(name)) {
                busy[name] = nil
            }
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        // The menu opens with current state already in it (watch keeps it
        // fresh); this refresh is belt-and-suspenders and updates in place.
        refresh()
    }

    // MARK: - Menu bar icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        // Animated only while a Limac-initiated command is in flight — that's
        // our own knowledge, not an inferred VM state. limactl reports no
        // transitional status, so CLI-driven changes go straight empty↔full.
        if !busy.isEmpty {
            startIconAnimation()
        } else {
            stopIconAnimation()
            button.image = instances.contains(where: { $0.isRunning })
                ? LimeIcon.full
                : LimeIcon.empty
        }
    }

    private func startIconAnimation() {
        guard iconAnimation == nil else { return }
        iconFrame = 0
        statusItem.button?.image = LimeIcon.frames[0]
        let timer = Timer(timeInterval: LimeIcon.frameInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.iconFrame = (self.iconFrame + 1) % LimeIcon.frames.count
            self.statusItem.button?.image = LimeIcon.frames[self.iconFrame]
        }
        // .common keeps the wave moving while the menu is open (menu tracking
        // runs the run loop outside the default mode).
        RunLoop.main.add(timer, forMode: .common)
        iconAnimation = timer
    }

    private func stopIconAnimation() {
        iconAnimation?.invalidate()
        iconAnimation = nil
    }

    // MARK: - Menu building

    private func rebuildMenu() {
        menu.removeAllItems()

        if limactlPath == nil {
            addDisabled("Lima isn't installed", to: menu)
            menu.addItem(copyItem(title: "Copy “brew install lima”",
                                  payload: "brew install lima"))
            menu.addItem(linkItem(title: "What's Lima?",
                                  url: "https://lima-vm.io"))
        } else if let unsupportedVersion {
            addDisabled("Lima \(unsupportedVersion) found — Limac needs Lima ≥ 2.0", to: menu)
            menu.addItem(copyItem(title: "Copy “brew upgrade lima”",
                                  payload: "brew upgrade lima"))
        } else if instances.isEmpty {
            addDisabled("No Lima VMs yet", to: menu)
            menu.addItem(copyItem(title: "Copy “limactl create template://docker”",
                                  payload: "limactl create template://docker"))
            menu.addItem(linkItem(title: "Browse Lima's Template Catalog",
                                  url: "https://lima-vm.io/docs/templates/"))
            addDisabled("Limac picks new VMs up automatically", to: menu)
        } else {
            for instance in instances {
                menu.addItem(instanceItem(for: instance))
            }
        }

        menu.addItem(.separator())
        menu.addItem(settingsItem())
        let quit = NSMenuItem(title: "Quit Limac", action: #selector(quitApp(_:)),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func settingsItem() -> NSMenuItem {
        let settings = NSMenu()
        settings.autoenablesItems = false

        let launch = NSMenuItem(title: "Launch Limac at Login",
                                action: #selector(toggleLaunchAtLogin(_:)),
                                keyEquivalent: "")
        launch.target = self
        launch.state = LoginItem.isEnabled ? .on : .off
        launch.isEnabled = true
        launch.image = Self.symbolImage("power")
        launch.toolTip = "Registers the running binary "
            + "(\(LoginItem.executablePath ?? "?")) as a launch agent; "
            + "takes effect at your next login"
        settings.addItem(launch)

        settings.addItem(.separator())

        let terminals = NSMenu()
        terminals.autoenablesItems = false
        for app in TerminalApp.allCases where app.isInstalled {
            let item = NSMenuItem(title: app.rawValue,
                                  action: #selector(selectTerminal(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = app.rawValue
            item.state = Preferences.terminalApp == app ? .on : .off
            item.isEnabled = true
            if let url = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            terminals.addItem(item)
        }
        let terminalsParent = NSMenuItem(title: "Terminal Emulator", action: nil,
                                         keyEquivalent: "")
        terminalsParent.image = Self.symbolImage("terminal")
        terminalsParent.submenu = terminals
        terminalsParent.isEnabled = true
        settings.addItem(terminalsParent)

        let parent = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        parent.image = Self.symbolImage("gearshape")
        parent.submenu = settings
        parent.isEnabled = true
        return parent
    }

    private func instanceItem(for instance: Instance) -> NSMenuItem {
        let item = NSMenuItem()
        // "Starting…" and "degraded" come from the hostagent's event stream
        // (limactl watch --json): the list says Running from the moment the
        // hostagent is up, but readiness — ssh, boot scripts — is only done
        // at the `running` event, the same moment `limactl start` prints
        // READY. This covers starts made from a terminal too.
        let isBooting = watchAvailable && instance.isRunning
            && booting.contains(instance.name)
        let isDegraded = instance.isRunning && degraded.contains(instance.name)
        let detail: String
        if let operation = busy[instance.name] {
            item.image = dotImage(color: .systemOrange, description: "operation in progress")
            detail = operation.label
        } else if isBooting {
            item.image = dotImage(color: .systemOrange, description: "starting")
            detail = "Starting…"
        } else if isDegraded {
            item.image = dotImage(color: .systemOrange, description: "running, degraded")
            detail = "Running (degraded)"
        } else {
            item.image = dotImage(for: instance.status)
            // Status text is limactl's, verbatim; the shape is configured,
            // not live.
            detail = instance.statusLine
        }
        if #available(macOS 14.4, *) {
            item.title = instance.name
            item.subtitle = detail
        } else {
            item.title = "\(instance.name) — \(detail)"
        }
        item.submenu = actionsMenu(for: instance)
        item.isEnabled = true
        return item
    }

    private func actionsMenu(for instance: Instance) -> NSMenu {
        let name = instance.name
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let idle = busy[name] == nil

        // Only the plain transition verbs go quiet while an operation is in
        // flight (double-submit protection). The troubleshoot verbs below
        // stay live — they're the way out of a hung start, and limactl
        // itself accepts them in any state (verified: factory-reset works
        // mid-start; delete refuses with a clear error until Stopped, which
        // Limac surfaces verbatim).
        @discardableResult
        func add(_ title: String, _ action: Selector, symbol: String? = nil,
                 tooltip: String? = nil, enabled: Bool = true,
                 disabledWhileBusy: Bool = false) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.toolTip = tooltip
            item.image = symbol.flatMap(Self.symbolImage)
            item.isEnabled = enabled && (idle || !disabledWhileBusy)
            submenu.addItem(item)
            return item
        }

        if instance.isRunning {
            add("Stop", #selector(stopInstance(_:)), symbol: "stop.fill",
                tooltip: "limactl stop \(name)", disabledWhileBusy: true)
            add("Restart", #selector(restartInstance(_:)), symbol: "arrow.clockwise",
                tooltip: "limactl restart \(name)", disabledWhileBusy: true)
            add("Launch Shell", #selector(openShell(_:)), symbol: "terminal",
                tooltip: "limactl shell \(name)")
            if instance.isKubernetes {
                // Enabled by the kubeconfig's presence on the host, not by
                // the Running status — the file appears only once the
                // cluster's API server is actually reachable.
                add("Launch kubectl", #selector(openKubectlTerminal(_:)),
                    symbol: "helm",
                    tooltip: instance.kubeconfigReady
                        ? "Terminal with KUBECONFIG set to this cluster"
                        : "Waiting for the cluster to publish its kubeconfig",
                    enabled: instance.kubeconfigReady)
            }
        } else {
            add("Start", #selector(startInstance(_:)), symbol: "play.fill",
                tooltip: "limactl start \(name)", disabledWhileBusy: true)
        }

        submenu.addItem(.separator())

        if let message = instance.message, !message.isEmpty {
            add("Setup Notes…", #selector(showSetupNotes(_:)), symbol: "doc.text")
        }

        // Everything here is composed from fields limactl reports (name,
        // sshConfigFile, dir). FILE is a deliberate placeholder to edit.
        var copyCommands: [(String, String)] = [
            ("Shell Command", "limactl shell \(name)"),
        ]
        var copyPaths: [(String, String)] = []
        if let sshConfig = instance.sshConfigFile {
            let host = "lima-\(name)"
            copyCommands.append(("SSH Command", "ssh -F \"\(sshConfig)\" \(host)"))
            copyCommands.append(("SCP Command", "scp -F \"\(sshConfig)\" FILE \(host):~/"))
            copyCommands.append(
                ("rsync Command", "rsync -av -e \"ssh -F \(sshConfig)\" FILE \(host):~/"))
            copyPaths.append(("SSH Config Path", sshConfig))
        }
        if let kubeconfig = instance.kubeconfigPath {
            copyCommands.append(
                ("KUBECONFIG env var", "export KUBECONFIG=\"\(kubeconfig)\""))
            copyCommands.append(
                ("kubectl Command", "kubectl --kubeconfig \"\(kubeconfig)\" get nodes"))
            copyPaths.append(("Kubeconfig Path", kubeconfig))
        }
        if let dir = instance.dir {
            copyPaths.append(("VM Directory Path", dir))
        }

        let copyMenu = NSMenu()
        copyMenu.autoenablesItems = false
        for (index, group) in [copyCommands, copyPaths].enumerated() {
            if index > 0, !group.isEmpty { copyMenu.addItem(.separator()) }
            for (title, payload) in group {
                let item = NSMenuItem(title: title,
                                      action: #selector(copyPayload(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = payload
                item.toolTip = payload
                item.isEnabled = true
                copyMenu.addItem(item)
            }
        }
        let copyParent = NSMenuItem(title: "Copy to Clipboard", action: nil, keyEquivalent: "")
        copyParent.image = Self.symbolImage("doc.on.doc")
        copyParent.isEnabled = true
        copyParent.submenu = copyMenu
        submenu.addItem(copyParent)

        // Delegated to `limactl autostart` so the CLI and the app never
        // disagree; the checkmark reflects Lima's own launch agent.
        let autostartOn = Autostart.isEnabled(name)
        let autostartItem = add(
            "Start at Login", #selector(toggleAutostart(_:)), symbol: "power",
            tooltip: "limactl autostart \(autostartOn ? "disable" : "enable") \(name)")
        autostartItem.state = autostartOn ? .on : .off

        submenu.addItem(.separator())

        if instance.isRunning {
            add("Force Stop", #selector(forceStopInstance(_:)),
                symbol: "exclamationmark.octagon",
                tooltip: "limactl stop -f \(name)")
        }
        add("Factory Reset…", #selector(factoryResetInstance(_:)), symbol: "eraser",
            tooltip: "limactl factory-reset \(name)")

        submenu.addItem(.separator())

        add("Delete…", #selector(deleteInstance(_:)), symbol: "trash",
            tooltip: instance.isProtected
                ? "Protected in Lima (limactl protect); unprotect to delete"
                : "limactl delete \(name)",
            enabled: !instance.isProtected)
        let protectItem = add(
            "Protect from Deletion", #selector(toggleProtection(_:)), symbol: "lock",
            tooltip: "limactl \(instance.isProtected ? "unprotect" : "protect") \(name)")
        protectItem.state = instance.isProtected ? .on : .off

        return submenu
    }

    private static func symbolImage(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func dotImage(for status: String) -> NSImage? {
        let color: NSColor
        switch status {
        case "Running": color = .systemGreen
        case "Broken": color = .systemOrange
        default: color = .tertiaryLabelColor
        }
        return dotImage(color: color, description: status)
    }

    private func dotImage(color: NSColor, description: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: "circle.fill",
                            accessibilityDescription: description)?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        return image
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func copyItem(title: String, payload: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(copyPayload(_:)),
                              keyEquivalent: "")
        item.target = self
        item.representedObject = payload
        item.isEnabled = true
        return item
    }

    private func linkItem(title: String, url: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openLink(_:)),
                              keyEquivalent: "")
        item.target = self
        item.representedObject = url
        item.isEnabled = true
        return item
    }

    // MARK: - Instance actions

    @objc private func startInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(.start, on: name)
    }

    @objc private func stopInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(.stop, on: name)
    }

    @objc private func restartInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(.restart, on: name)
    }

    @objc private func forceStopInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(.forceStop, on: name)
    }

    @objc private func factoryResetInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let alert = destructiveAlert(
            title: "Factory reset “\(name)”?",
            body: "Runs `limactl factory-reset \(name)`. Wipes the machine back to "
                + "a fresh state while keeping its configuration.",
            confirmTitle: "Factory Reset")
        guard confirmed(alert) else { return }
        perform(.factoryReset, on: name)
    }

    @objc private func deleteInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let instance = instances.first(where: { $0.name == name }) else { return }
        let diskNote = instance.disk.map { " and its \(Instance.formatBytes($0)) disk" } ?? ""
        let alert = destructiveAlert(
            title: "Delete “\(name)”?",
            body: "Runs `limactl delete \(name)`. Erases the VM\(diskNote). "
                + "This can't be undone.",
            confirmTitle: "Delete")
        guard confirmed(alert) else { return }
        perform(.delete, on: name)
    }

    private func perform(_ operation: Operation, on name: String) {
        guard let limactlPath else { return }
        busy[name] = operation
        rebuildMenu()
        updateIcon()
        let arguments = operation.arguments(for: name)
        Limactl.run(limactlPath, arguments) { [weak self] result in
            guard let self else { return }
            self.busy[name] = nil
            self.updateIcon()
            if !result.succeeded {
                self.showError(command: "limactl \(arguments.joined(separator: " "))",
                               result: result)
            }
            self.refresh()
        }
    }

    @objc private func openShell(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let limactlPath else { return }
        TerminalLauncher.openShell(limactlPath: limactlPath, instanceName: name)
    }

    @objc private func openKubectlTerminal(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let path = instances.first(where: { $0.name == name })?.kubeconfigPath
        else { return }
        TerminalLauncher.openKubectl(kubeconfigPath: path)
    }

    // MARK: - Settings actions

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if LoginItem.isEnabled {
            LoginItem.disable()
        } else {
            do {
                try LoginItem.enable()
            } catch {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Couldn't register the login item"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
        rebuildMenu()
    }

    @objc private func selectTerminal(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let app = TerminalApp(rawValue: raw) else { return }
        Preferences.terminalApp = app
        rebuildMenu()
    }

    @objc private func toggleProtection(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let limactlPath,
              let instance = instances.first(where: { $0.name == name }) else { return }
        let verb = instance.isProtected ? "unprotect" : "protect"
        Limactl.run(limactlPath, [verb, name]) { [weak self] result in
            guard let self else { return }
            if !result.succeeded {
                self.showError(command: "limactl \(verb) \(name)", result: result)
            }
            self.refresh()
        }
    }

    @objc private func toggleAutostart(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let limactlPath else { return }
        let verb = Autostart.isEnabled(name) ? "disable" : "enable"
        Limactl.run(limactlPath, ["autostart", verb, name]) { [weak self] result in
            guard let self else { return }
            if !result.succeeded {
                self.showError(command: "limactl autostart \(verb) \(name)",
                               result: result)
            }
            self.rebuildMenu()
        }
    }

    @objc private func showSetupNotes(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let instance = instances.first(where: { $0.name == name }),
              let message = instance.message, !message.isEmpty else { return }

        // Lima's own post-start message, rendered by Lima with real paths —
        // the same text `limactl start` prints.
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let textView = NSTextView(frame: NSRect(origin: .zero,
                                                size: scroll.contentSize))
        textView.string = message
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize,
                                              weight: .regular)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "\(name) — setup notes"
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Copy All")
        if alert.runModal() == .alertSecondButtonReturn {
            copyToPasteboard(message)
        }
    }

    // MARK: - Small helpers

    @objc private func copyPayload(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? String else { return }
        copyToPasteboard(payload)
    }

    @objc private func openLink(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        // Quit leaves VMs running — they're Lima's, not ours — but say so,
        // in case the user assumed quitting the app stops them.
        let running = instances.filter(\.isRunning)
        if !running.isEmpty {
            let names = running.map(\.name).joined(separator: ", ")
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = running.count == 1
                ? "VM “\(names)” is still running"
                : "\(running.count) VMs are still running"
            alert.informativeText = "Quitting Limac won't stop your VMs — "
                + "they'll keep running in the background."
            alert.addButton(withTitle: "Quit Anyway")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        NSApp.terminate(nil)
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func destructiveAlert(title: String, body: String,
                                  confirmTitle: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = body
        let confirm = alert.addButton(withTitle: confirmTitle)
        confirm.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    private func confirmed(_ alert: NSAlert) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showError(command: String, result: CommandResult) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "\(command) failed"
        alert.informativeText = String(result.stderr.suffix(1500))
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}
