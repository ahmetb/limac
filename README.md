<div align="center">
  <img src="img/logo.svg" width="128" alt="Limac logo — a lime slice">
  <h1>Limac</h1>
  <p><strong>Control your <a href="https://github.com/lima-vm/lima">Lima</a> VMs from the macOS menu bar.</strong></p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
    <img src="https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white" alt="Swift 5.10">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT">
  </p>
</div>

Glance at the menu bar to see which VMs are running. Click to start, stop, or
open a shell. Limac wraps `limactl` and nothing else: a VM you start from the
terminal appears in the menu, and every action Limac takes is a `limactl`
command you could type yourself.

<!-- TODO: replace placeholders with real captures -->

| VM list | VM controls |
| :---: | :---: |
| 📷 *coming soon* | 📷 *coming soon* |
<!--
| <img src="img/vm-list.png" width="380" alt="The menu listing VMs with their status"> | <img src="img/vm-controls.png" width="380" alt="The controls for one VM"> |
-->

## Features

- **Glanceable state.** The icon is green when a VM is running, gray when
  none are, and pulses while an operation is in flight.
- **One-click control.** Start, stop, and restart each VM. Each menu entry
  shows Lima's status and the configured CPUs, memory, and disk.
- **Live updates.** State comes from `limactl watch` events, not polling.
  Stop a VM from a terminal and the menu updates at once.
- **Shell access.** Open a shell in Ghostty, iTerm2, WezTerm, Alacritty, or
  Terminal.
- **Kubernetes support.** Cluster VMs are marked in the menu. Launch a
  terminal with `KUBECONFIG` set, or copy the kubeconfig path, env var, or a
  `kubectl` command.
- **Copy commands.** Ready-to-paste `limactl shell`, `ssh`, `scp`, and
  `rsync` commands, plus the ssh-config and VM directory paths.
- **Setup notes.** Lima's post-start message for each VM — for docker VMs,
  the exact `docker context create` commands.
- **Start at login.** Per VM through `limactl autostart`, and Limac itself as
  a login item.
- **Safety.** Destructive actions ask once. Protected VMs cannot be deleted.
  Quitting Limac leaves your VMs running.
- **Transparency.** Every menu item's tooltip shows the exact `limactl`
  command it runs.

## Installation

There is no packaged release yet; build from source. You need macOS 14 or
later, a Swift toolchain (Xcode 15+ or the Command Line Tools), and Lima 2.0
or later on your `PATH` (`brew install lima`).

```sh
git clone https://github.com/ahmetb/limac
cd limac
swift run
```

A signed app bundle and a Homebrew cask are planned.

## Scope

Limac is a minimal app to control your existing Lima VMs, so it does not aim
for a full feature set. It does not create VMs, manage containers, or show
data that `limactl` does not provide. Product and design docs live in
[docs/](docs/).

## License

Limac is released under the [MIT License](LICENSE). It is an independent
project, not affiliated with the Lima project.
