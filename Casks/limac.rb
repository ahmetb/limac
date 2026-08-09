# Stamped by .github/workflows/release.yml on every tagged release; inert
# placeholders until the first tag.
cask "limac" do
  version "0.1.0"
  sha256 "901895942cdd218211b7731240e88a3a36c2e13d0d22da8d4dc7b21797769714"

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
    Limac is not signed with an Apple Developer ID certificate. If macOS
    blocks the first launch, right-click Limac.app and choose Open; on
    macOS 15 or newer, also approve it under System Settings -> Privacy &
    Security -> "Open Anyway". Updates installed by the app itself do not
    re-trigger this warning.
  EOS

  zap trash: [
    "~/Library/LaunchAgents/dev.limac.plist",
    "~/Library/Preferences/dev.limac.plist",
  ]
end
