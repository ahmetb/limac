# Open questions

Decisions to settle before wireframes. Each comes with a recommendation, so
"no objection" is a valid answer.

1. **Does Create-VM make v1?** Control-only would be even leaner and still
   covers the daily loop; creation is a first-five-minutes feature.
   **Recommendation:** keep it, in its minimal template-picker form. The first
   five minutes are when people decide whether the app stays installed.

2. **How Docker-flavored do we get?** Nothing at all, a one-click context
   setup, or a full context-switching UI. **Recommendation:** the one-click,
   nothing more. It serves the biggest use case without changing what the app
   is.

3. **Minimum macOS version?** 14 gets us modern `MenuBarExtra` behavior; 13
   widens reach a little. **Recommendation:** 14+.

4. **Start-at-login mechanism:** our own launchd plists, or delegate to
   `limactl autostart`? **Recommendation:** delegate. The CLI and the app
   should never disagree about what happens at boot.

5. **App updates:** Homebrew cask only, or Sparkle in-app updates too?
   **Recommendation:** cask only for v1. Our audience has Homebrew by
   definition (that's how Lima got there).

6. **Which templates make the shortlist?** Lima ships forty-plus.
   **Recommendation:** ubuntu-lts (default), docker, podman, debian, fedora,
   alpine.

7. **What happens to VMs when Limac quits?** **Recommendation:** nothing —
   they keep running, and the quit confirmation says so. Limac is a remote
   control, not a lifeline.

8. **Naming and icon.** Is "Limac" final? The menu bar glyph is effectively
   the entire brand surface — worth real design time early.

9. **Telemetry.** **Recommendation:** none, and say so in the README as a
   feature.
