# Open questions

Decisions to settle before wireframes. Each comes with a recommendation, so
"no objection" is a valid answer.

## Settled

- **No VM creation or deletion in Limac** (decided 2026-08-07). v1 controls
  instances you already have: start, stop (with a force-stop fallback),
  restart, and factory reset for troubleshooting. Making and removing
  machines stays in the CLI; the app's empty state hands you a copyable
  `limactl create` command instead.

## Open

1. **How Docker-flavored do we get?** Nothing at all, a one-click context
   setup, or a full context-switching UI. **Recommendation:** the one-click,
   nothing more. It serves the biggest use case without changing what the app
   is.

2. **Minimum macOS version?** 14 gets us modern `MenuBarExtra` behavior; 13
   widens reach a little. **Recommendation:** 14+.

3. **Start-at-login mechanism:** our own launchd plists, or delegate to
   `limactl autostart`? **Recommendation:** delegate. The CLI and the app
   should never disagree about what happens at boot.

4. **App updates:** Homebrew cask only, or Sparkle in-app updates too?
   **Recommendation:** cask only for v1. Our audience has Homebrew by
   definition (that's how Lima got there).

5. **What happens to VMs when Limac quits?** **Recommendation:** nothing —
   they keep running, and the quit confirmation says so. Limac is a remote
   control, not a lifeline.

6. **Naming and icon.** Is "Limac" final? The menu bar glyph is effectively
   the entire brand surface — worth real design time early.

7. **Telemetry.** **Recommendation:** none, and say so in the README as a
   feature.
