# Limac

Limac puts your [Lima](https://lima-vm.io) VMs where your Wi-Fi and battery
live: glance at the menu bar to see what's running, click to start, stop, or
open a shell. It wraps `limactl` and nothing else.

This is a first, native-elements version: an `NSStatusItem` with a plain
`NSMenu` — no custom panel, no dock icon, no windows beyond standard alerts.

- Menu bar icon: green dot when at least one VM is running, gray outline
  otherwise.
- One menu item per instance showing Lima's status verbatim and the
  configured shape (CPUs · memory · disk), with a submenu:
  Start / Stop / Restart, Open Shell (in Terminal.app), Setup Notes…
  (Lima's own post-start message), Copy (shell / SSH command), Force Stop,
  Factory Reset…, and Delete… (disabled for `protect`ed instances).
  Destructive actions ask once. Tooltips show the exact `limactl` command
  each item runs.
- State is pushed by `limactl watch` — a VM started or stopped from a
  terminal updates the menu and icon the same way. No polling loop.

Product and design docs live in [docs/](docs/).

## Requirements

- macOS 14 or later
- A Swift toolchain (Xcode 15+ or the Command Line Tools)
- Lima ≥ 2.0 on your `PATH`: `brew install lima`

## Run

From the repo root:

```sh
swift run
```

The first build takes a minute; then the Limac icon appears at the right end
of the menu bar. Quit from the menu ("Quit Limac") or with `Ctrl-C` in the
terminal. Quitting Limac leaves your VMs running — they're Lima's, not ours.

## Not here yet

Settings (launch at login, per-instance autostart, preferred terminal), a
signed/notarized app bundle, and everything listed under "Deliberately out of
scope" in [docs/prd.md](docs/prd.md).
