# Limac — Product Requirements (v1 draft)

**Status:** draft for discussion · **Updated:** August 2026

## One-liner

Limac puts your Lima VMs where your Wi-Fi and battery live: glance at the menu
bar to see what's running, click to start, stop, or open a shell. It wraps
`limactl` and nothing else.

## Why build it

Lima has become the default way to run Linux VMs on a Mac — it powers
Colima, Rancher Desktop, and Finch — but Lima itself lives entirely in the
terminal. People who use it daily repeat the same four actions: check whether a
VM is running, start it, open a shell, stop it. Each one is a terminal
round-trip for a question the menu bar could answer at a glance.

Docker Desktop proved how much an always-visible status icon matters. It also
proved how much you can bolt onto one. Limac keeps the one idea worth keeping —
glanceable state with one-click control — and leaves out the dashboard, the
container UI, the account, and the license.

## Who it's for

A developer with one to three Lima instances (typically a `docker` template VM
or a Linux dev environment) who starts a VM in the morning and stops it at
night. They chose Lima on purpose. Limac saves them terminal round-trips; it
doesn't hide the tool from them.

Not for: people managing fleets of VMs, CI systems, or people who have never
heard of Lima.

## Product principles

1. **The menu bar is the whole app.** No dock icon, no main window. If a
   feature needs a window to explain itself, it probably doesn't belong in v1.
   (A small settings pane is the only exception.)
2. **Wrap, don't replace — and never invent.** `limactl` stays the source of
   truth. A VM started from the terminal shows up in Limac; anything Limac
   does is visible from the CLI. And the rule cuts deeper than files: if
   limactl doesn't provide a piece of data or a verb, Limac doesn't show it.
   No inferred state, no guesses.
3. **Do less, instantly.** The panel opens with current state already in it —
   no spinner. VM operations take as long as they take; everything around
   them is immediate.
4. **No surprises.** Destructive actions ask once. The app is silent
   otherwise.

## The v1 experience

Wireframe-level sketches for everything below live in [design.md](design.md).

### First run

Limac looks for `limactl`. Found: it adopts your existing instances and that's
the whole onboarding. Missing: a single screen pointing at `brew install lima`.

### The glance

The menu bar icon has two resting states: green when at least one VM is
running, gray when nothing is — plus orange while an operation Limac itself
started is still in flight. Most days that's the whole answer; anything more
detailed is one click away.

### The panel

Each instance row shows Lima's status verbatim (Running, Stopped, Broken —
whatever `limactl list` reports), the name, and the configured shape (CPUs ·
memory · disk). Per instance:

- **Start / Stop / Restart**
- **Open shell** — opens your terminal running `limactl shell <name>`
- **Setup notes** — Lima's own post-start message for this VM
- **Copy** — the shell command or the SSH connection details
- **Troubleshoot** — Force stop, Factory reset… Factory reset wipes the
  machine back to a fresh state while keeping its configuration, so it asks
  once, plainly.
- **Delete…** — asks once; disabled for instances marked with Lima's
  `protect` flag

While an operation runs, the row shows a spinner; the new status arrives
through Lima's event stream. No progress bars or time estimates — Lima
reports status transitions, not progress, so Limac doesn't guess. A VM
started or stopped from a terminal updates the panel exactly the same way.

### Setup notes (the Docker story)

Lima templates ship a `message` that Lima renders with real paths — the same
text `limactl start` prints. For docker VMs that's the exact
`docker context create …` commands. Limac shows it with a copy button, for
any VM whose template provides one. Running Docker is the most common reason
a Mac runs Lima, and this covers it with zero detection logic of our own.

### When there are no VMs

Limac doesn't create instances — that stays in the terminal, where Lima's
templates and flags live. The empty state still helps: a one-line hint, a
copyable starter command (`limactl create template://docker`), and a link to
Lima's template catalog. The moment the instance exists, Limac picks it up
automatically.

### Settings

Launch Limac at login. Per-instance start-at-login, delegated to
`limactl autostart` so the CLI and the app never disagree. Preferred terminal
(Terminal, iTerm2, Ghostty, …). Nothing else.

## Deliberately out of scope for v1

| Not doing | Why |
|---|---|
| Creating VMs | Creation's sharp edges (templates, sizing, downloads) stay in the CLI. Limac manages machines you made; it doesn't make them. |
| Container / image UI | That's Docker Desktop's turf. We stop at the VM boundary. |
| Notifications | Lima has no notification feature, and reacting to event-stream changes would ping you about other people's terminal actions. |
| Boot progress bars and time estimates | Lima reports status transitions, not progress. Anything more would be invented. |
| Live usage stats and battery impact | limactl exposes configured CPU/memory/disk only. The day Lima grows usage or power data, we adopt it. |
| Editing `lima.yaml` (in-app or via `limactl edit`) | Punted to v2. |
| Log viewer | limactl has no logs command; nothing to wrap. |
| Bundling Lima itself | Homebrew installs and updates it better; revisit only if demand is loud. |
| Kubernetes anything | Different product. |
| Lima networking (vmnet, tunnels) | Needs sudo, serves few; CLI territory. |
| Snapshots, clone, extra disks | Real features, wrong release. Candidates for later. |
| Windows / Linux ports | It's a Mac menu bar app. |

## What quality means here

- The panel opens instantly and is never stale: state is pushed by
  `limactl watch` events, not polled on a timer.
- The daily loop — glance, start, shell, stop — needs zero terminal commands.
- The idle footprint disappears: near-zero CPU, small memory, no daemon of our
  own.
- It feels native: SwiftUI, correct in light and dark mode, respects Reduce
  Motion, fully keyboard-navigable.

## After v1 (candidates, unranked)

- Edit config via `limactl edit`
- Port-forward list per instance (the event stream already carries this)
- Global hotkey to open the panel
- "Open in VS Code" via Remote-SSH and Lima's generated SSH config
- Snapshot take / restore (`limactl snapshot`)
- Live usage and battery-impact display — if and when Lima exposes the data
- A minimal create flow — only if its absence clearly hurts

## Technical grounding (for the wireframe and build phases)

- Swift + SwiftUI `MenuBarExtra` (window style — a custom panel, not a native
  NSMenu), macOS 14+.
- State comes from `limactl list --json`; live updates from `limactl watch`,
  which streams status changes and port-forward events. No polling loop.
- Every action shells out to `limactl`. Limac links nothing from Lima and never
  bypasses it.
- Requires Lima ≥ 2.0 on the PATH (Homebrew). Friendly version gate at startup.
- Distributed as a GitHub release plus a Homebrew cask; ad-hoc signed for
  now (no Developer ID), with in-app updates via Sparkle — see
  [updates.md](updates.md).
