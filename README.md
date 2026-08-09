<div align="center">
  <img src="img/logo.svg" width="128" alt="Limac logo — a lime slice">
  <h1>Limac</h1>
  <p><strong>Your <a href="https://github.com/lima-vm/lima">Lima</a> virtual machines, one glance away — in the macOS menu bar.</strong></p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
    <img src="https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white" alt="Swift 5.10">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT">
  </p>
</div>

Limac puts your Lima VMs where your Wi-Fi and battery live: glance at the menu
bar to see what's running; click to start, stop, or open a shell. It wraps
`limactl` and nothing else — a VM started from a terminal shows up in Limac,
and anything Limac does is plain `limactl` you could have typed yourself.

<div align="center">
  <!-- TODO: hero screenshot
  <img src="img/screenshot-menu.png" width="480" alt="The Limac menu showing a running docker VM and a stopped Kubernetes cluster">
  -->
  <p>📷 <em>Screenshot coming soon — the menu with a running docker VM and a stopped Kubernetes cluster.</em></p>
</div>

## Features

- **Glanceable state.** A lime-slice icon that's green when a VM is running,
  a gray outline when nothing is, and pulses while an operation is in flight.
- **One-click control.** Start, Stop, and Restart per instance, with each
  VM's status and configured shape (CPUs · memory · disk) right in the menu.
- **Always fresh, never polling.** State is pushed by `limactl watch` events
  and a filesystem watcher — stop a VM from a terminal and the menu updates
  the same instant, with readiness-aware status while a VM boots.
- **Launch a shell** in your preferred terminal: Ghostty, iTerm2, WezTerm,
  Alacritty, or Terminal.
- **Kubernetes-aware.** Cluster VMs are marked in the menu; launch a
  `kubectl`-ready terminal with `KUBECONFIG` already set, or copy the
  kubeconfig path, env var, or a ready-made `kubectl` command.
- **Copy to clipboard.** Ready-to-paste `limactl shell`, `ssh`, `scp`, and
  `rsync` commands, plus the ssh-config and VM directory paths.
- **Setup notes.** Lima's own post-start message per VM — for docker VMs,
  that's the exact `docker context create …` commands — one copy away.
- **Start at login.** Per VM via `limactl autostart`, and Limac itself as a
  login item.
- **Safety rails.** Destructive actions ask once; Lima's `protect` flag is
  honored (and toggleable); deleting requires stopping first; quitting with
  VMs running warns you — and quitting leaves your VMs alone. They're Lima's,
  not ours.
- **Nothing up its sleeve.** Every menu item's tooltip shows the exact
  `limactl` command it runs.

## Screenshots

<!-- TODO: replace placeholders with real captures (light + dark) -->

| The menu | Kubernetes actions | Settings |
| :---: | :---: | :---: |
| 📷 *coming soon* | 📷 *coming soon* | 📷 *coming soon* |

## Philosophy

1. **The menu bar is the whole app.** No dock icon, no dashboard, no windows
   beyond standard alerts.
2. **Wrap, don't replace — and never invent.** `limactl` stays the source of
   truth. If Lima doesn't provide a piece of data or a verb, Limac doesn't
   show it: no inferred state, no guesses, no progress bars made up on the
   spot.
3. **Do less, instantly.** The menu opens with current state already in it —
   no spinner. VM operations take as long as they take; everything around
   them is immediate.
4. **No surprises.** Destructive actions ask once. The app is silent
   otherwise.

Docker Desktop proved how much an always-visible status icon matters — and
how much you can bolt onto one. Limac keeps the one idea worth keeping,
glanceable state with one-click control, and leaves out the dashboard, the
container UI, the account, and the license agreement.

The full product and design docs live in [docs/](docs/).

## Status

Limac is young. It needs macOS 14+ and Lima ≥ 2.0, and currently runs from
source; a signed, notarized app bundle and a Homebrew cask are planned, and
installation instructions will land here with the first release.

## License

Limac is released under the [MIT License](LICENSE). It is an independent
project, not affiliated with the Lima project.
