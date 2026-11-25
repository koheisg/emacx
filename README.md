# Emacx

A macOS menu bar app that fills in missing Emacs-style keybindings and opens the Spotlight clipboard history with ⌘⇧V.

## Features

### Keybindings

macOS text fields already support many Emacs-style bindings out of the box (C-a, C-e, C-b, C-f, C-n, C-p, C-d, C-h, C-k, and more). Emacx adds the two that are missing:

| Key | Action | Keys actually sent |
|---|---|---|
| C-w | Delete the previous word | ⌥⌫ |
| C-u | Delete from the cursor to the beginning of the line | ⌘⇧← then ⌫ |

These are not remapped while a terminal is frontmost (Terminal, iTerm2, WezTerm, kitty, Alacritty, Ghostty, Warp, Hyper), so the shell's own C-w / C-u keep working.

### Clipboard history

Press ⌘⇧V to open Spotlight's clipboard history (macOS 26 or later). Emacx sends your Spotlight shortcut as configured in System Settings (⌘Space by default) and then ⌘4.

Turn on clipboard history in System Settings > Spotlight first. Emacx itself no longer records the clipboard.

## Requirements

- macOS 13 or later
- Swift 5.10 or later (Xcode or Command Line Tools)

## Install

```sh
brew install --cask koheisg/tap/emacx
```

On first launch, grant Emacx access in System Settings > Privacy & Security > Accessibility. Key monitoring starts automatically once access is granted.

The app is only ad-hoc signed (not notarized), so the cask removes the quarantine attribute after installation to let it launch.

## Build from source

```sh
make app                          # builds .build/Emacx.app
cp -r .build/Emacx.app /Applications/
open /Applications/Emacx.app
```

Other make targets:

- `make build`: debug build
- `make release`: release build
- `make dist`: build the `.app` and zip it for release
- `make run`: build the `.app` and launch it
- `make reload`: rebuild, quit the running Emacx, reset its Accessibility permission, and relaunch it (you only need to turn the permission back on)
- `make clean`: remove build artifacts

### Notes

- `make app` builds a universal binary (arm64 and x86_64) and requires Xcode.
- The app is only ad-hoc signed. If you copy a built `.app` to another Mac, Gatekeeper will block it; run `xattr -dr com.apple.quarantine /Applications/Emacx.app` to allow it.
- Because of the ad-hoc signature, the Accessibility permission is lost on every rebuild. After updating, remove Emacx from the list in System Settings and add it again.
- To keep the permission across local rebuilds, create a self-signed code signing certificate named `Emacx Local Signing` in your login keychain. `make app` signs with it when it exists.

## Known issues

- When controlling another Mac via Screen Sharing or similar apps, Emacx on the controlling Mac still remaps C-w / C-u. As a result, C-w / C-u do not behave as the shell expects even when a terminal is frontmost on the remote Mac.
- For C-w, C-u, and ⌘⇧V, Emacx swallows only the key-down event; the key-up event is passed through.

## License

[MIT](LICENSE)
