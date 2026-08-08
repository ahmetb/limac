# Ideas

Raw material for the scope discussion. Nothing here is committed — the PRD is
the cut we're proposing, and this is the pile it was cut from. Costs are rough:
**cheap** (hours), **medium** (days), **pricey** (a week or more, or ongoing
maintenance).

One rule filters everything: if limactl doesn't provide the data or the verb,
the idea is out (or waits until Lima provides it).

## The spine

Glance at state · start · stop · open shell. If any one of these is missing,
the app has no reason to exist. Everything else is garnish.

## Small touches worth fighting for

1. **Copy as CLI command** (cheap). Any action can reveal its `limactl`
   equivalent. It teaches the tool and builds trust with people who are
   rightly suspicious of GUIs over CLIs.
2. **Setup notes, surfaced** (cheap). Lima renders each template's `message`
   with real paths — the docker context commands, podman socket paths, and
   so on. Showing it with a copy button answers "it's running, now what?"
   for every template, with zero detection logic.
3. **Stuck-VM escape hatch** (cheap). A graceful stop can hang. After a
   polite wait, offer Force stop (`limactl stop -f`) instead of an eternal
   spinner.
4. **Protected instances** (cheap). The `protected` field is right there in
   the JSON. Honor it: Delete is disabled, with a note saying why.
5. **Terminal of choice** (cheap). Open shell in Terminal, iTerm2, Ghostty,
   kitty — detect what's installed, remember the preference.
6. **Reuse `limactl autostart`** (cheap). Lima already knows how to start
   instances at login. Delegating means the CLI and the app never disagree
   about what happens at boot.

## Wildcards — fun, undecided (all limactl-backed)

- **Open in VS Code.** Lima generates an SSH config per instance
  (`sshConfigFile` in the JSON); VS Code Remote-SSH can ride it. One menu
  item, real payoff for dev-environment VMs. Medium.
- **Port-forward list.** The event stream reports forwards as they open. A
  submenu listing them — with "open in browser" for HTTP ports — is cheap,
  and better than it sounds.
- **Snapshot before risky work.** `limactl snapshot` exists. One-click
  "snapshot now", restore from the panel. Genuinely useful, but it drags a
  whole state model into the UI. Pricey.
- **VM screenshot.** `limactl screenshot` exists. Mostly a toy; a fun one.

## Punted to v2

- **Edit Config** (`limactl edit <name>` in the user's terminal). A real
  limactl verb, cut from v1 to keep the panel small.

## Ideas we should say no to

- **Creating VMs.** Even a minimal create dialog drags in naming, sizing,
  template curation, download progress, and failure modes. `limactl create`
  already does it well. (Was in the first PRD draft; cut after discussion on
  2026-08-07. Delete stayed in — cleanup is routine, and Lima's `protect`
  flag plus a confirmation contain the risk.)
- **Notifications.** Lima has no notification feature. Building our own on
  top of the event stream means a `limactl start` in someone's terminal makes
  Limac ping them — noise nobody asked for. Revisit, at most, for operations
  Limac itself initiated.
- **Boot progress bars and time estimates.** Lima reports status
  transitions, not progress — and VMs start outside the app too. Estimates
  would be invented state. (Cut from an earlier draft on 2026-08-07.)
- **Log viewer.** limactl has no logs command; there is nothing to wrap.
- **Container and image lists.** The moment we show containers we're competing
  with Docker Desktop on its home turf, and the "lean" thesis dies.
- **Bundling the Lima runtime.** "Just works" is tempting, but then we own
  Lima's upgrade bugs, packaging, and security patches forever. Homebrew
  already does this job well.
- **A form-based YAML editor.** Lima's config surface is enormous. A form that
  covers a tenth of it is worse than no form: it teaches people the wrong
  mental model of where truth lives.
- **Metrics and graphs.** limactl exposes no live load, memory, or battery
  data — only the configured shape. People rightly worry about VMs draining
  batteries, so the day Lima grows usage or power stats, adopt them; until
  then there is nothing honest to draw.
- **Fleet / remote management.** Wrong persona. One Mac, a few VMs.
- **Auto-stop VMs on sleep or low battery.** Clever right up until it kills
  someone's overnight job.
