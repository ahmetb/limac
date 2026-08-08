# Limac — v1 design: wireframes and feature map

**Status:** pre-wireframe sketches · **Updated:** August 2026

These sketches turn [prd.md](prd.md) into screens. One hard rule governs
everything here:

> Every pixel maps to a limactl command or a field limactl already returns.
> Limac infers nothing, keeps no state of its own, and invents no data.

Verified against limactl 2.2.0: each instance in `limactl list --json`
carries `name, status, cpus, memory, disk, arch, vmType, dir, sshAddress,
sshLocalPort, sshConfigFile, protected, message, config`, and
`limactl watch` streams change events. limactl has no feature for logs,
live load or memory stats, battery impact, boot progress, or notifications
— so Limac has no UI for them.

The next stage is real wireframing; these boxes fix the content of each
screen, not its final look.

## Feature map

Every feature names its limactl source:

| UI element | limactl source |
|---|---|
| Instance rows (name, status, shape, ssh) | `list --json` fields, verbatim |
| Icon: green / gray | any instance `status == "Running"` |
| Start / Stop / Restart | `start`, `stop`, `restart` |
| Force Stop | `stop -f` |
| Factory Reset… | `factory-reset` |
| Delete… (disabled when protected) | `delete`; the `protected` field |
| Open Shell | `limactl shell <name>` in the user's terminal |
| Setup Notes… | the instance `message` field, verbatim |
| Copy (shell / ssh command) | composed from `name`, `sshConfigFile` |
| Start VMs at login | `limactl autostart` |
| Panel freshness | `limactl watch` triggers re-read of `list --json` |

App-level conveniences that touch no Lima data: launch Limac at login, and
which terminal app to open shells in. That's the entire settings surface.

Punted to v2: Edit Config (`limactl edit`).

## A. Menu bar icon — two states

```
●  green: at least one VM is Running        ○  gray: nothing running
```

No animation states, no badges. The panel carries the detail.

## B. The panel — a typical day

```
        ┌──────────────────────────────────────┐
        │ ● docker              [Shell] [Stop] │
        │   Running · 4 CPU · 8 GB · 60 GB     │
        │                                      │
        │ ○ ubuntu-dev                 [Start] │
        │   Stopped · 8 CPU · 12 GB · 100 GB   │
        ├──────────────────────────────────────┤
        │ Settings…                       Quit │
        └──────────────────────────────────────┘
```

- Status dot and text are limactl's `status` string, verbatim. A VM
  reporting `Broken` shows exactly that word — remedies live with the other
  row actions (section C).
- The detail line is configured shape from `list --json`, not live usage —
  limactl doesn't provide usage.
- Primary buttons: `[Start]` on stopped rows; `[Shell] [Stop]` on running.
- While a verb runs, the row's button shows a spinner; the row updates when
  `watch` reports the new status. No progress bars, no estimates — a VM
  started from a terminal updates the panel exactly the same way.
- Quit leaves VMs running (they're Lima's, not ours).

## C. Row actions beyond the primary buttons — the full verb set

```
        ┌────────────────────────────┐
        │ Open Shell                 │  limactl shell docker
        │ Restart                    │  limactl restart docker
        │ Force Stop                 │  limactl stop -f docker
        │ Factory Reset…             │  limactl factory-reset docker
        │ Setup Notes…               │  shows lima's `message` field
        │ Copy                     ▸ │  shell command · ssh command
        ├────────────────────────────┤
        │ Delete…                    │  limactl delete docker
        └────────────────────────────┘
```

- Presentation note: these deserve more prominence on the row than a hidden
  ⋯ menu; the exact treatment is decided in the wireframing stage.
- Each item's tooltip shows the exact command it runs — the UI teaches the
  CLI.
- `Delete…` is disabled with a note when the JSON says `protected: true`.

## D. Setup Notes — lima's message, not our detection

```
        ┌ docker — setup notes ──────────────────────┐
        │ To run `docker` on the host, run the       │
        │ following commands:                        │
        │ ------                                     │
        │ docker context create lima-docker \        │
        │   --docker "host=unix://~/.lima/docker/    │
        │   sock/docker.sock"                        │
        │ docker context use lima-docker             │
        │ docker run hello-world                     │
        │ ------                                     │
        │                        [Copy All] [Done]   │
        └────────────────────────────────────────────┘
```

- This is the `message` field rendered by Lima with real paths — the same
  text `limactl start` prints. It covers Docker context setup and every
  other template that ships a message (podman, k8s, …). Zero detection
  logic in Limac.

## E. Empty states

```
   No VMs yet:                          Lima not installed:
   ┌────────────────────────────┐       ┌────────────────────────────┐
   │      No Lima VMs yet       │       │    Lima isn't installed    │
   │                            │       │                            │
   │  Create one in a terminal: │       │  ┌──────────────────────┐  │
   │  ┌──────────────────────┐  │       │  │ brew install lima  ⧉ │  │
   │  │ limactl create       │  │       │  └──────────────────────┘  │
   │  │  template://docker ⧉ │  │       │  What's Lima? ↗            │
   │  └──────────────────────┘  │       └────────────────────────────┘
   │  Browse all templates ↗    │
   │                            │
   │  Limac picks it up the     │
   │  moment it exists.         │
   └────────────────────────────┘
```

## F. Delete confirmation

```
        ┌───────────────────────────────────┐
        │  Delete "ubuntu-dev"?             │
        │                                   │
        │  Runs `limactl delete ubuntu-dev`.│
        │  Erases the VM and its 100 GB     │
        │  disk. This can't be undone.      │
        │                                   │
        │           [ Cancel ]  [ Delete ]  │
        └───────────────────────────────────┘
```

## G. Settings — one small pane, nothing more

```
        ┌ Limac Settings ────────────────────┐
        │ ☑ Launch Limac at login            │
        │ Open shells in:  [ Terminal    ▾ ] │
        │                                    │
        │ Start VMs at login                 │
        │   ☑ docker                         │
        │   ☐ ubuntu-dev                     │
        │   (managed via `limactl autostart`)│
        └────────────────────────────────────┘
```

No notification settings (there are no notifications). No update settings
(Homebrew's job).
