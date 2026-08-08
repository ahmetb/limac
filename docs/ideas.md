# Ideas

Raw material for the scope discussion. Nothing here is committed — the PRD is
the cut we're proposing, and this is the pile it was cut from. Costs are rough:
**cheap** (hours), **medium** (days), **pricey** (a week or more, or ongoing
maintenance).

## The spine

Glance at state · start · stop · open shell · notify when ready. If any one of
these is missing, the app has no reason to exist. Everything else is garnish.

## Small touches worth fighting for

1. **Ready notification with an "Open shell" button** (cheap). Starts are slow
   and everyone tabs away. The notification closes the loop — one click and
   you're in the VM you asked for a minute ago.
2. **Live start phases** (medium). "Booting…" beats a spinner. Lima emits
   lifecycle events; surfacing them turns dead waiting into visible progress.
3. **Time-to-ready memory** (cheap). Remember how long the last few starts
   took and show an honest estimate ("usually ready in ~45s"). Tiny effort;
   feels like magic the second time you see it.
4. **Copy as CLI command** (cheap). Any menu action can reveal its `limactl`
   equivalent. It teaches the tool and builds trust with people who are
   rightly suspicious of GUIs over CLIs.
5. **Broken-state triage** (medium). When an instance reports Broken, offer
   restart, factory-reset, and open-the-log — a path forward instead of a red
   dot and a shrug.
6. **Stuck-VM escape hatch** (cheap). A graceful stop can hang. After a
   polite wait, offer Force stop (`limactl stop -f`) instead of an eternal
   spinner.
7. **Icon micro-states** (cheap). A subtle animation while anything is
   starting or stopping; an attention badge when something is broken. The icon
   is the app — it should earn its pixels.
8. **Terminal of choice** (cheap). Open shell in Terminal, iTerm2, Ghostty,
   kitty — detect what's installed, remember the preference.
9. **Docker context one-click** (cheap). See the PRD; it's the one integration.
10. **Reuse `limactl autostart`** (cheap). Lima already knows how to start
    instances at login. Delegating means the CLI and the app never disagree
    about what happens at boot.
11. **Protected instances** (cheap). Lima's `protect` flag exists to prevent
    accidental deletion. Honor it: Delete is disabled, with a note saying
    why.

## Wildcards — fun, undecided

- **Open in VS Code.** Lima generates an SSH config per instance; VS Code
  Remote-SSH can ride it. One menu item, real payoff for dev-environment VMs.
  Medium.
- **Port-forward list.** The event stream reports forwards as they open. A
  submenu listing them — with "open in browser" for HTTP ports — is cheap, and
  better than it sounds.
- **Snapshot before risky work.** One-click "snapshot now", restore from the
  menu. Genuinely useful, but it drags a whole state model into the UI.
  Pricey.
- **VM screenshot.** `limactl screenshot` exists. Mostly a toy; a fun one.

## Ideas we should say no to

- **Creating VMs.** Even a minimal create dialog drags in naming, sizing,
  template curation, download progress, and failure modes. `limactl create`
  already does it well. (Was in the first PRD draft; cut after discussion on
  2026-08-07. Delete stayed in — cleanup is routine, and Lima's `protect`
  flag plus a confirmation contain the risk.)
- **Container and image lists.** The moment we show containers we're competing
  with Docker Desktop on its home turf, and the "lean" thesis dies.
- **Bundling the Lima runtime.** "Just works" is tempting, but then we own
  Lima's upgrade bugs, packaging, and security patches forever. Homebrew
  already does this job well.
- **A form-based YAML editor.** Lima's config surface is enormous. A form that
  covers a tenth of it is worse than no form: it teaches people the wrong
  mental model of where truth lives.
- **Metrics and graphs.** A menu bar app that grows a dashboard becomes the app
  we built this to escape.
- **Fleet / remote management.** Wrong persona. One Mac, a few VMs.
- **Auto-stop VMs on sleep or low battery.** Clever right up until it kills
  someone's overnight job.
