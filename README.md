# Clutch

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
| **Thermal** | Live thermal state via SMC |
| **Battery** | Battery status and health |
| **CPU** | CPU usage |
| **Screenshot** | Screenshot capture |
| **Clipboard** | Clipboard history/manager |

---

## Requirements

- macOS 26 (Tahoe) or later
- Xcode Command Line Tools (provides `swift`):
  ```bash
  xcode-select --install
  ```

## Running it

Clutch is a Swift Package Manager project driven by a `Makefile`. It must run as a signed `.app` bundle (not the raw binary) — otherwise macOS won't grant or persist TCC permissions like Audio Capture.

### Run in development

```bash
make run
```

This builds a debug binary, wraps it into `Clutch.app`, ad-hoc code-signs it, kills any running instance, and reopens it.

### Build a release .app bundle

```bash
make app
```

Creates `Clutch.app` in the project folder (release configuration).

### Install to /Applications

```bash
make install
```

Copies the release bundle to `/Applications/Clutch.app`. To launch it automatically on login: **System Settings → General → Login Items → add Clutch**.

### Clean build artifacts

```bash
make clean
```

Removes `.build/` and `Clutch.app`.

---

## Architecture

```
Sources/Clutch/
├── main.swift                       # NSApplication entry point
├── AppDelegate.swift                # Hides from Dock (LSUIElement)
├── MenuBar/
│   └── MenuBarController.swift      # NSStatusItem + NSPopover
├── Views/
│   ├── ClutchPopoverView.swift      # Root SwiftUI view (tile grid + settings)
│   └── ModuleSectionView.swift      # Collapsible section per module
└── Modules/
    ├── Module.swift                 # Protocol every module conforms to
    ├── VolumeControl/
    ├── Thermal/
    ├── Battery/
    ├── CPU/
    ├── Screenshot/
    └── Clipboard/
```

### Adding a new module

1. Create `Sources/Clutch/Modules/MyModule/`
2. Implement the `Module` protocol:

```swift
final class MyModule: Module {
    let id = "my-module"
    let name = "My Module"
    let sfSymbol = "star.fill"
    let tintColor: Color = .blue

    @MainActor
    func makeContent() -> AnyView {
        AnyView(MyModuleView())
    }
}
```

3. Register it in `ClutchPopoverView.swift`:

```swift
private let allModules: [any Module] = [
    VolumeControlModule(),
    ThermalModule(),
    BatteryModule(),
    CPUModule(),
    ScreenshotModule(),
    ClipboardModule(),
    MyModule(),
]
```

---

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free to use, modify, and share for any noncommercial purpose. Commercial use requires the licensor's permission.
