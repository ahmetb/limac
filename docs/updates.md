# In-app updates

How the packaged Limac.app keeps itself current. The moving parts and the
release flow live in [RELEASING.md](../RELEASING.md); this doc records the
design and its rationale.

## Shape

[Sparkle 2](https://sparkle-project.org) checks
`https://raw.githubusercontent.com/ahmetb/limac/main/appcast.xml` daily (and
on demand via the menu's "Check for Updates…"), downloads the release zip
from GitHub Releases, verifies its EdDSA signature against the
`SUPublicEDKey` baked into Info.plist, swaps the bundle atomically, and
relaunches. The appcast carries only the newest release — Sparkle never
offers anything older. This replicates the pipeline proven in
[Iris](https://github.com/ahmetb/Iris).

## Decisions

- **Why Sparkle at all** (reversing the earlier "cask only" lean,
  [open-questions.md](open-questions.md)): a menu bar app that's always
  running is exactly the app people never reinstall by hand, and `brew
  upgrade` only helps people who run it. The cask remains, with
  `auto_updates true` so brew defers to Sparkle instead of fighting it.
- **The limactl-only rule doesn't apply.** That rule governs what Limac
  shows about Lima. Self-maintenance is the app's own concern; Sparkle is
  the first and only third-party framework in the app.
- **Bare executables don't update.** `swift run` produces no bundle —
  nothing for Sparkle to replace, no Info.plist to read. The updater and
  its menu item exist only when `Bundle.main.bundleIdentifier` is non-nil,
  i.e. in the packaged app. The dev loop stays `swift run`.
- **Ad-hoc signing means EdDSA is the whole trust story.** With no
  Developer ID identity, Sparkle's only integrity check is the ed25519
  signature on the zip. Consequences: the release workflow refuses to ship
  unsigned enclosures, and losing the private key strands the update train
  (see RELEASING.md). A happy side effect of updating in-place: Sparkle
  updates don't carry a fresh quarantine flag, so Gatekeeper's unsigned-app
  warning fires on first install only.
- **`CFBundleVersion` = the semver tag**, stamped into the bundle at
  package time by `scripts/make-app.sh`. Sparkle compares this against the
  appcast's `sparkle:version`; the template's `0.0.0` placeholder is never
  shipped by CI.
- **`CFBundleIdentifier` is `dev.limac` forever.** It matches the
  UserDefaults suite and the LaunchAgent label, so preferences carry over
  between `swift run` and the packaged app — and Sparkle refuses to install
  an update whose bundle identifier changed.
- **No update settings.** Automatic checks are on
  (`SUEnableAutomaticChecks`), which also skips Sparkle's second-launch
  consent prompt. The only UI is "Check for Updates…" in the menu.

## Known warts

- A LaunchAgent created by a `swift run` build points at the old executable
  path; after switching to the packaged app, toggle "Launch Limac at Login"
  off and on once.
- The XPC services inside Sparkle.framework are only needed by sandboxed
  apps (Limac isn't); they ship anyway, signed, to stay close to the stock
  framework.
