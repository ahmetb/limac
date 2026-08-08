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
  Start / Stop / Restart, Open Shell (in your preferred terminal),
  Setup Notes… (Lima's own post-start message), Copy Commands (shell, ssh,
  scp, rsync, plus the ssh-config and VM directory paths),
  Start at Login (via `limactl autostart`), Force Stop, Factory Reset…, and
  Delete… (disabled for `protect`ed instances). Destructive actions ask
  once. Tooltips show the exact `limactl` command each item runs. While an
  operation is in flight the plain transition verbs pause, but the
  troubleshoot verbs stay available — they're the way out of a hung start.
- State is pushed by `limactl watch` — a VM started or stopped from a
  terminal updates the menu and icon the same way. No polling loop.
- A Settings submenu: launch Limac at login, and which terminal shells open
  in — Ghostty, iTerm2, WezTerm, Alacritty, or Terminal, defaulting to the
  first of those you have installed. (Warp is not offered: it has no way to
  open a tab running a given command.)

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

## Notes

"Launch Limac at Login" registers the binary you're currently running (e.g.
`.build/…/debug/Limac`) as a user launch agent, since `swift run` produces no
app bundle. If you move or clean the build, toggle it off and on again to
re-point it. It takes effect at your next login.

## Not here yet

A signed/notarized app bundle, and everything listed under "Deliberately out
of scope" in [docs/prd.md](docs/prd.md).
