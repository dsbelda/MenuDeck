# MenuDeck

**[English](README.md) | [Español](README.es.md)**

A modular macOS menu bar utility. Lives in the top-right corner of the screen and groups system tools as expandable modules with Apple's Liquid Glass design.

> **Requires macOS 26 (Tahoe) or later.**

---

## Features

- Liquid Glass UI — built with SwiftUI's modern `.regularMaterial` / glass styling introduced in macOS 26
- Modular architecture — each tool is a self-contained module, expanded on demand from a tile grid
- No Dock icon — lives only in the menu bar (`LSUIElement`)
- Configurable menu bar icon (app icon, temperature, battery, CPU, or RAM) and default module on open

### Modules

| Module | Description |
|---|---|
| **Volume** | Per-application volume sliders and mute toggles via CoreAudio HAL |
| **Output** | Switch the audio output device |
| **Temperature** | Live sensor temperatures via SMC |
| **Battery** | Charge, health, cycles and screen-on time |
| **CPU / RAM** | Per-core usage and memory breakdown |
| **Storage** | Free space on every mounted volume |
| **FPS** | GPU utilisation and the system Metal HUD toggle |
| **Network** | Throughput, local IP and Wi-Fi signal |
| **Awake** | Keep the Mac and display awake, optionally on a timer |
| **Screenshots** | Full screen, area or window capture |
| **Clipboard** | Clipboard history |
| **Colour** | Screen colour picker with history |
| **Dev Tools** | Quick launcher for your terminal, editors and coding agents |
| **Brew** | Outdated and installed Homebrew packages |
| **Ports** | Listening TCP ports, and stopping whatever holds one |
| **Shortcuts** | Run Shortcuts from the menu bar |
| **Bluetooth** | Connect and disconnect paired devices |
| **Trash** | Size of the Trash, and emptying it |
| **Uninstall** | Remove an app together with the files it left behind |
| **Finder** | Hidden files, path bar, status bar and desktop icons |

Every module can be switched off in Settings and given a global shortcut.

---

## Requirements

- macOS 26 (Tahoe) or later
- Xcode Command Line Tools (provides `swift`):
  ```bash
  xcode-select --install
  ```

## Running it

MenuDeck is a Swift Package Manager project driven by a `Makefile`. It must run as a signed `.app` bundle (not the raw binary) — otherwise macOS won't grant or persist TCC permissions like Audio Capture.

### Run in development

```bash
make run
```

This builds a debug binary, wraps it into `MenuDeck.app`, ad-hoc code-signs it, kills any running instance, and reopens it.

### Build a release .app bundle

```bash
make app
```

Creates `MenuDeck.app` in the project folder (release configuration).

### Install to /Applications

```bash
make install
```

Copies the release bundle to `/Applications/MenuDeck.app`. To launch it automatically on login: **System Settings → General → Login Items → add MenuDeck**.

### Clean build artifacts

```bash
make clean
```

Removes `.build/` and `MenuDeck.app`.

---

## Architecture

```
Sources/MenuDeck/
├── main.swift                    # NSApplication entry point
├── AppDelegate.swift             # Accessory app (no Dock icon), launch + teardown
├── MenuBar/
│   └── MenuBarController.swift   # NSStatusItem + NSPopover, global hot keys
├── Views/
│   ├── MenuDeckPopoverView.swift # Root SwiftUI view (tiles + settings)
│   ├── PopoverState.swift        # Shown module, and the whileShown modifier
│   └── TileLayout.swift          # Grid / icons / list / row tile layouts
├── Support/                      # Shell, hot keys, login item, timers
└── Modules/
    ├── Module.swift              # Protocol every module conforms to
    ├── ModuleRegistry.swift      # The list of modules, and which are on
    └── <Name>/                   # One folder per module: Module, Manager, View
```

### Adding a new module

1. Create `Sources/MenuDeck/Modules/MyModule/`
2. Implement the `Module` protocol:

```swift
final class MyModule: Module {
    let id = "my-module"
    let name: LocalizedStringResource = "My Module"
    let sfSymbol = "star.fill"
    let tintColor: Color = .blue

    @MainActor
    func makeContent() -> AnyView {
        AnyView(MyModuleView())
    }
}
```

3. Register it in `Modules/ModuleRegistry.swift`:

```swift
static let all: [any Module] = [
    VolumeControlModule(),
    // …
    MyModule(),
]
```

If the module polls or animates, start and stop it with `.whileShown(start, stop:)` rather than
`onAppear`/`onDisappear`: closing the popover does not tear the SwiftUI tree down, so those never
fire and the module would keep running in a closed popover.

---

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free to use, modify, and share for any noncommercial purpose. Commercial use requires the licensor's permission.
