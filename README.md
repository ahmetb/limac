<div align="center">
  <img src="img/logo.svg" width="128" alt="Limac logo, a lime slice">
  <h1>Limac</h1>
  <p><strong>Control your <a href="https://github.com/lima-vm/lima">Lima</a> VMs from the macOS menu bar.</strong></p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
    <img src="https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white" alt="Swift 5.10">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT">
  </p>
</div>

Limac is a minimal, **menu bar-only** macOS app that lets you manage your
[Lima](https://github.com/lima-vm/lima) VMs and launch terminal or `kubectl`
sessions on them. Every action it takes is a `limactl` command you could type
yourself.

| VM list | VM controls |
| :---: | :---: |
| <img src="img/vm-list.png" width="380" alt="The menu listing VMs with their status"> | <img src="img/vm-controls.png" width="380" alt="The controls for one VM"> |

## Installation

You need macOS 14 or later and Lima 2.0 or later on your `PATH`
(`brew install lima`).

```sh
brew tap ahmetb/limac https://github.com/ahmetb/limac
brew install --cask limac
```

Or grab `Limac-vX.Y.Z.zip` from the
[releases page](https://github.com/ahmetb/limac/releases).

> [!WARNING]
> The app is not signed with an Apple Developer ID certificate, so macOS may
> block the first launch. Clear the quarantine flag:
>
> ```sh
> xattr -dr com.apple.quarantine /Applications/Limac.app
> ```
>
> Or approve it by hand:
>
> - Right-click Limac.app and choose Open.
> - Click Open in the security dialog.
> - On macOS 15 or newer, also allow it under System Settings → Privacy &
>   Security.
>
> The app checks for updates daily and installs them in place; those updates
> don't re-trigger the warning.

## Features

- See what's running at a glance. The lime is full when a VM is running and
  faded when none are, and the menu updates the moment a VM changes, even one
  you started from a terminal.
- Start, stop, or restart a VM in one click.
- Open a shell in your terminal: Ghostty, iTerm2, WezTerm, Alacritty, or
  Terminal.
- Use Kubernetes VMs right away: launch a `kubectl` terminal with
  `KUBECONFIG` set, or copy the kubeconfig.
- Smaller conveniences live in each VM's menu: copy `ssh` commands, read
  Lima's setup notes, and start VMs at login.

## Local Development

To build from source, install a Swift toolchain (Xcode 15 or the Command Line
Tools) and:

```sh
git clone https://github.com/ahmetb/limac
cd limac
swift run
```

## Scope

Limac is a minimal app to control the Lima VMs you already have, so don't
expect a full feature set. It does not create VMs or manage containers, and
if `limactl` doesn't report something, Limac doesn't show it. Product and
design docs live in [docs/](docs/).

## License

[MIT](LICENSE). Limac is an independent project, not affiliated with the
Lima project.

The lime artwork (the logo above and the menu bar icon) is the lime emoji
from [Noto Emoji](https://github.com/googlefonts/noto-emoji), © Google,
used under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). The menu
bar icon is a monochrome adaptation of it.
