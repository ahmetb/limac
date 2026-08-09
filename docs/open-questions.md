# Open questions

Decisions to settle before wireframes. Each open item comes with a
recommendation, so "no objection" is a valid answer.

## Settled

- **No VM creation in Limac** (2026-08-07). v1 controls instances you
  already have: start, stop (with a force-stop fallback), restart, factory
  reset for troubleshooting — and delete, behind a confirmation that honors
  Lima's `protect` flag. Making new machines stays in the CLI; the app's
  empty state hands you a copyable `limactl create` command instead.
- **The limactl-only rule** (2026-08-07). Every pixel maps to a limactl
  command or a `limactl list --json` field; Limac infers nothing and keeps
  no state of its own. Cut accordingly: notifications, boot progress and
  time estimates, log access, live usage/battery stats. The Docker
  convenience is Lima's own `message` field ("Setup notes"), not socket
  detection. Start-at-login delegates to `limactl autostart`. Edit Config
  is punted to v2.
- **Custom panel over native NSMenu** (2026-08-07). Inline Start/Stop
  buttons and designed empty states beat maximum menu-nativeness. Row
  actions deserve more prominence than a hidden overflow menu — exact
  treatment to be decided in wireframing. Quit leaves VMs running.
- **App updates: Sparkle in-app updates plus a Homebrew cask** (2026-08-09,
  reversing the earlier cask-only recommendation). Replicates the release
  pipeline proven in [Iris](https://github.com/ahmetb/Iris): a tag-triggered
  workflow EdDSA-signs the zip and publishes a one-item appcast; the cask
  sets `auto_updates true` so brew and Sparkle don't fight. Sparkle is a
  deliberate exception to the limactl-only rule: that rule governs what
  Limac shows about *Lima*, not how the app maintains itself. Details in
  [updates.md](updates.md).

## Open

1. **Minimum macOS version?** 14 gets us modern `MenuBarExtra` behavior; 13
   widens reach a little. **Recommendation:** 14+.

2. **Naming and icon.** Is "Limac" final? The menu bar glyph is effectively
   the entire brand surface — worth real design time early.

3. **Telemetry.** **Recommendation:** none, and say so in the README as a
   feature.
