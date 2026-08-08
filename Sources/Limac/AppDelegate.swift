import AppKit

/// The menu bar is the whole app: an NSStatusItem with a plain NSMenu.
/// State comes from `limactl list --json`; freshness from `limactl watch`.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private var limactlPath: String?
    private var instances: [Instance] = []
    /// Instance name → in-flight verb label ("Starting…"). Rows with an
    /// entry here show the label and disable their actions.
    private var busy: [String: String] = [:]
    /// Set when the installed Lima is older than what Limac requires.
    private var unsupportedVersion: String?
    private var watcher: LimaWatcher?
    private var refreshScheduled = false

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
            self.watcher = LimaWatcher(limactlPath: path) { [weak self] in
                self?.scheduleRefresh()
            }
            self.watcher?.start()
            self.refresh()
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
            self.instances = Instance.parseList(result.stdout)
            self.rebuildMenu()
            self.updateIcon()
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
        let anyRunning = instances.contains { $0.isRunning }
        if anyRunning {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
            let image = NSImage(systemSymbolName: "circle.fill",
                                accessibilityDescription: "Limac: a VM is running")?
                .withSymbolConfiguration(config)
            image?.isTemplate = false
            button.image = image
        } else {
            let image = NSImage(systemSymbolName: "circle",
                                accessibilityDescription: "Limac: no VMs running")
            image?.isTemplate = true
            button.image = image
        }
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
        let terminalsParent = NSMenuItem(title: "Open Shells In", action: nil,
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
        item.image = dotImage(for: instance.status)
        // Status text is limactl's, verbatim; the shape is configured, not live.
        let detail = busy[instance.name] ?? instance.statusLine
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
            add("Open Shell", #selector(openShell(_:)), symbol: "terminal",
                tooltip: "limactl shell \(name)")
        } else {
            add("Start", #selector(startInstance(_:)), symbol: "play.fill",
                tooltip: "limactl start \(name)", disabledWhileBusy: true)
        }

        submenu.addItem(.separator())

        if let message = instance.message, !message.isEmpty {
            add("Setup Notes…", #selector(showSetupNotes(_:)), symbol: "doc.text")
        }

        let copyMenu = NSMenu()
        copyMenu.autoenablesItems = false
        let copyParent = NSMenuItem(title: "Copy Commands", action: nil, keyEquivalent: "")
        copyParent.image = Self.symbolImage("doc.on.doc")
        copyParent.isEnabled = true
        copyParent.submenu = copyMenu
        let shellCommand = "limactl shell \(name)"
        let shellItem = NSMenuItem(title: "Shell Command",
                                   action: #selector(copyPayload(_:)), keyEquivalent: "")
        shellItem.target = self
        shellItem.representedObject = shellCommand
        shellItem.toolTip = shellCommand
        shellItem.isEnabled = true
        copyMenu.addItem(shellItem)
        if let sshConfig = instance.sshConfigFile {
            let sshCommand = "ssh -F \(sshConfig) lima-\(name)"
            let sshItem = NSMenuItem(title: "SSH Command",
                                     action: #selector(copyPayload(_:)), keyEquivalent: "")
            sshItem.target = self
            sshItem.representedObject = sshCommand
            sshItem.toolTip = sshCommand
            sshItem.isEnabled = true
            copyMenu.addItem(sshItem)
        }
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
        if instance.isProtected {
            add("Unprotect", #selector(toggleProtection(_:)), symbol: "lock.open",
                tooltip: "limactl unprotect \(name)")
        } else {
            add("Protect from Deletion", #selector(toggleProtection(_:)), symbol: "lock",
                tooltip: "limactl protect \(name)")
        }

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
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: status)?
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
        perform(["start", name], busyLabel: "Starting…", on: name)
    }

    @objc private func stopInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(["stop", name], busyLabel: "Stopping…", on: name)
    }

    @objc private func restartInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(["restart", name], busyLabel: "Restarting…", on: name)
    }

    @objc private func forceStopInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        perform(["stop", "-f", name], busyLabel: "Force stopping…", on: name)
    }

    @objc private func factoryResetInstance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let alert = destructiveAlert(
            title: "Factory reset “\(name)”?",
            body: "Runs `limactl factory-reset \(name)`. Wipes the machine back to "
                + "a fresh state while keeping its configuration.",
            confirmTitle: "Factory Reset")
        guard confirmed(alert) else { return }
        perform(["factory-reset", name], busyLabel: "Factory resetting…", on: name)
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
        perform(["delete", name], busyLabel: "Deleting…", on: name)
    }

    private func perform(_ arguments: [String], busyLabel: String, on name: String) {
        guard let limactlPath else { return }
        busy[name] = busyLabel
        rebuildMenu()
        Limactl.run(limactlPath, arguments) { [weak self] result in
            guard let self else { return }
            self.busy[name] = nil
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
                ? "“\(names)” is still running"
                : "\(running.count) VMs are still running"
            alert.informativeText = "Quitting Limac doesn't stop your Lima VMs — "
                + "\(names) will keep running in the background. "
                + "Stop them from Limac or with `limactl stop`."
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
