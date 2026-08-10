# Stamped by .github/workflows/release.yml on every tagged release; inert
# placeholders until the first tag.
cask "limac" do
  version "0.1.2"
  sha256 "11d71b9e79fe8955deff300a74117fe29c12790e99a7945d055f9242da0848de"

  url "https://github.com/ahmetb/limac/releases/download/v#{version}/Limac-v#{version}.zip"
  name "Limac"
  desc "Control Lima VMs from the macOS menu bar"
  homepage "https://github.com/ahmetb/limac"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The app updates itself via Sparkle; brew upgrade skips it unless --greedy.
  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Limac.app"

  caveats <<~EOS
    Limac is not signed with an Apple Developer ID certificate.
    macOS may block the first launch. Clear the quarantine flag:

      xattr -dr com.apple.quarantine /Applications/Limac.app

    Or approve it by hand:
      - Right-click Limac.app and choose Open.
      - Click Open in the security dialog.
      - On macOS 15 or newer, also allow it under System Settings ->
        Privacy & Security -> "Open Anyway".

    Updates installed by the app itself do not re-trigger this warning.
  EOS

  zap trash: [
    "~/Library/LaunchAgents/dev.limac.plist",
    "~/Library/Preferences/dev.limac.plist",
  ]
end
