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
2. **Wrap, don't replace.** `limactl` stays the source of truth. A VM started
   from the terminal shows up in Limac; anything Limac does is visible from the
   CLI. Limac never touches Lima's files behind `limactl`'s back.
3. **Do less, instantly.** The menu opens with current state already in it — no
   spinner. VM operations take as long as they take; everything around them is
   immediate.
4. **No surprises.** Destructive actions ask once. Long actions notify when
   done. The app is silent otherwise.

## The v1 experience

### First run

Limac looks for `limactl`. Found: it adopts your existing instances and that's
the whole onboarding. Missing: a single screen pointing at `brew install lima`.

### The glance

The menu bar icon reflects overall state: something running, everything
stopped, working (a subtle animation while a VM starts or stops), or needs
attention (a VM is broken). Most days you get your answer without clicking.

### The menu

Each instance shows a status dot, its name, and its shape (CPUs · memory ·
disk). Per instance:

- **Start / Stop / Restart**
- **Open shell** — opens your terminal running `limactl shell <name>`
- **Copy** — the shell command or the SSH connection details
- **Edit config** — opens `lima.yaml` in your editor; Limac doesn't edit YAML
- **Troubleshoot** — for stuck or broken instances: Force stop, Factory
  reset…, Open log. Factory reset wipes the machine back to a fresh state
  while keeping its configuration, so it asks once, plainly.
- **Delete…** — asks once; disabled for instances marked with Lima's
  `protect` flag

### Starting a VM

A start takes anywhere from thirty seconds to a couple of minutes. Limac shows
the live phase in the menu (pulling image → booting → provisioning → ready),
driven by Lima's own event stream, and posts a notification when the VM is
ready — with an **Open shell** button on it. You click start and tab away; the
machine comes to find you.

### When there are no VMs

Limac doesn't create instances — that stays in the terminal, where Lima's
templates and flags live. The empty state still helps: a one-line hint, a
copyable starter command (`limactl create template://docker`), and a link to
Lima's template catalog. The moment the instance exists, Limac picks it up
automatically.

### The one Docker convenience

Running Docker is the single most common reason a Mac runs Lima. For
docker-template VMs, one menu item sets up the Docker context (or copies the
`DOCKER_HOST` export). That's the whole integration.

### Settings

Launch Limac at login. Per-instance start-at-login, delegated to
`limactl autostart` so the CLI and the app never disagree. Notification
toggles. Preferred terminal (Terminal, iTerm2, Ghostty, …).

## Deliberately out of scope for v1

| Not doing | Why |
|---|---|
| Creating VMs | Creation's sharp edges (templates, sizing, downloads) stay in the CLI. Limac manages machines you made; it doesn't make them. |
| Container / image UI | That's Docker Desktop's turf. We stop at the VM boundary. |
| Editing `lima.yaml` in-app | Your editor is better at YAML than we are. |
| Bundling Lima itself | Homebrew installs and updates it better; revisit only if demand is loud. |
| Kubernetes anything | Different product. |
| Log viewer | An "open log file" menu item; Console.app does the rest. |
| Resource graphs and metrics | Glanceable is not the same as a dashboard. |
| Lima networking (vmnet, tunnels) | Needs sudo, serves few; CLI territory. |
| Snapshots, clone, extra disks | Real features, wrong release. Candidates for later. |
| Windows / Linux ports | It's a Mac menu bar app. |

## What quality means here

- The menu opens instantly and is never stale: state is pushed by
  `limactl watch` events, not polled on a timer.
- The daily loop — glance, start, shell, stop — needs zero terminal commands.
- The idle footprint disappears: near-zero CPU, small memory, no daemon of our
  own.
- It feels native: SwiftUI, correct in light and dark mode, respects Reduce
  Motion, fully keyboard-navigable.

## After v1 (candidates, unranked)

- Port-forward list per instance (the event stream already carries this)
- Global hotkey to open the menu
- "Open in VS Code" via Remote-SSH and Lima's generated SSH config
- Snapshot take / restore
- Disk usage nudge ("ubuntu is using 92 of 100 GB")
- In-app updates via Sparkle
- A minimal create flow — only if its absence clearly hurts

## Technical grounding (for the wireframe and build phases)

- Swift + SwiftUI `MenuBarExtra`, macOS 14+.
- State comes from `limactl list --json`; live updates from `limactl watch`,
  which streams status changes and port-forward events. No polling loop.
- Every action shells out to `limactl`. Limac links nothing from Lima and never
  bypasses it.
- Requires Lima ≥ 2.0 on the PATH (Homebrew). Friendly version gate at startup.
- Signed and notarized; distributed as a GitHub release plus a Homebrew cask.
