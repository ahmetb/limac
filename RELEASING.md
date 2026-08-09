# Releasing Limac

Releases are cut by pushing a tag; everything else is automated.

```sh
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` then:

1. Builds a universal (arm64 + x86_64) `Limac.app` via `scripts/make-app.sh`,
   stamping the tag's version into the bundle's Info.plist — Sparkle compares
   the appcast's `sparkle:version` against the installed `CFBundleVersion`,
   so a release without this stamp would break the update chain.
2. Zips the app and signs the zip with the Sparkle EdDSA key
   (`SPARKLE_ED_PRIVATE_KEY` repo secret). Limac is ad-hoc signed, so this
   signature is the *only* integrity check updates get — the workflow fails
   hard if the secret is missing.
3. Publishes the GitHub release with the zip attached.
4. Regenerates `appcast.xml` (a single-item feed served from
   `raw.githubusercontent.com` on `main`), stamps the new version and sha256
   into `Casks/limac.rb`, and commits both back to `main`.

Installed apps see the new version within a day (or immediately via
"Check for Updates…"). Note raw.githubusercontent.com caches for a few
minutes, so the appcast lags the commit slightly.

## Update signing key

The private key is a base64-encoded 32-byte ed25519 seed. It lives in two
places:

- the `SPARKLE_ED_PRIVATE_KEY` GitHub Actions secret (write-only — it cannot
  be read back out of GitHub), and
- the maintainer's login keychain, item "Private key for signing Sparkle
  updates", account `limac` — this is the durable copy.

The matching public key is `SUPublicEDKey` in `scripts/Info.plist`.

Losing the private key permanently strands every installed updater (users
would have to reinstall by hand), and so would rotating it carelessly:
a new key must first ship in an update signed by the *old* key. Handle with
care.

To export the key from the keychain (e.g. to re-create the repo secret):

```sh
swift build   # fetches Sparkle's tools into .build/artifacts
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x /tmp/ed --account limac
gh secret set SPARKLE_ED_PRIVATE_KEY --repo ahmetb/limac < /tmp/ed
rm -P /tmp/ed
```

## Testing an update end-to-end locally

1. Build and install the "old" version:
   `scripts/make-app.sh 0.1.0 && cp -R dist/Limac.app /Applications/` and
   launch it once.
2. Build the "new" version: `scripts/make-app.sh 0.2.0`, then
   `cd dist && zip -r -y Limac-v0.2.0.zip Limac.app`.
3. Sign it: `.build/artifacts/sparkle/Sparkle/bin/sign_update --account limac
   Limac-v0.2.0.zip` (uses the keychain key) and paste the printed attributes
   into a hand-written `appcast.xml` whose enclosure URL points at
   `http://localhost:8000/Limac-v0.2.0.zip`.
4. Serve and point the installed app at it:
   ```sh
   python3 -m http.server 8000 &
   defaults write dev.limac SUFeedURL http://localhost:8000/appcast.xml
   ```
5. "Check for Updates…" in the installed app should offer 0.2.0, install it,
   and relaunch. Negative test: flip a byte in the zip and confirm Sparkle
   refuses it.
6. Clean up: `defaults delete dev.limac SUFeedURL`.

Note: silent scheduled updates install on *quit* and do not relaunch; only
the interactive "Install and Relaunch" button relaunches. Don't misread the
former as a failure.

## Manual release fallback

If Actions is down: run steps 1–3 of the workflow by hand
(`scripts/make-app.sh "$VERSION"`, `zip -r -y`, `sign_update`), create the
release with `gh release create`, and commit the regenerated `appcast.xml`
and cask bump yourself. The appcast XML shape is in
`.github/workflows/release.yml`.
