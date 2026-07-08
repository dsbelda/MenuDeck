# Clutch

**[English](README.md) | [Español](README.es.md)**

Una utilidad modular para la barra de menú de macOS. Vive en la esquina superior derecha de la pantalla y agrupa herramientas del sistema en módulos expandibles con el diseño Liquid Glass de Apple.

> **Requiere macOS 26 (Tahoe) o posterior.**

---

## Características

- UI Liquid Glass — construida con el moderno `.regularMaterial` / estilo cristal de SwiftUI introducido en macOS 26
- Arquitectura modular — cada herramienta es un módulo autónomo, que se expande bajo demanda desde una cuadrícula de iconos
- Sin icono en el Dock — vive únicamente en la barra de menú (`LSUIElement`)
- Icono de la barra de menú configurable (icono de la app, temperatura, batería, CPU o RAM) y módulo por defecto al abrir

### Módulos

| Módulo | Descripción |
|---|---|
| **Volume** | Sliders de volumen y silencio por aplicación vía CoreAudio HAL |
| **Thermal** | Estado térmico en vivo vía SMC |
| **Battery** | Estado y salud de la batería |
| **CPU** | Uso de CPU |
| **Screenshot** | Captura de pantalla |
| **Clipboard** | Historial/gestor del portapapeles |

---

## Requisitos

- macOS 26 (Tahoe) o posterior
- Xcode Command Line Tools (provee `swift`):
  ```bash
  xcode-select --install
  ```

## Cómo ejecutarlo

Clutch es un proyecto de Swift Package Manager gestionado con un `Makefile`. Debe ejecutarse como un `.app` firmado (no el binario en crudo) — de lo contrario macOS no concede ni conserva permisos TCC como el de Audio Capture.

### Ejecutar en desarrollo

```bash
make run
```

Esto compila un binario de depuración, lo empaqueta en `Clutch.app`, lo firma ad-hoc, mata cualquier instancia en ejecución y lo vuelve a abrir.

### Compilar un bundle .app de release

```bash
make app
```

Crea `Clutch.app` en la carpeta del proyecto (configuración release).

### Instalar en /Applications

```bash
make install
```

Copia el bundle de release a `/Applications/Clutch.app`. Para que se abra automáticamente al iniciar sesión: **Ajustes del Sistema → General → Elementos de inicio de sesión → añadir Clutch**.

### Limpiar artefactos de compilación

```bash
make clean
```

Elimina `.build/` y `Clutch.app`.

---

## Arquitectura

```
Sources/Clutch/
├── main.swift                       # Punto de entrada de NSApplication
├── AppDelegate.swift                # Oculta del Dock (LSUIElement)
├── MenuBar/
│   └── MenuBarController.swift      # NSStatusItem + NSPopover
├── Views/
│   ├── ClutchPopoverView.swift      # Vista raíz de SwiftUI (cuadrícula + ajustes)
│   └── ModuleSectionView.swift      # Sección colapsable por módulo
└── Modules/
    ├── Module.swift                 # Protocolo que implementa cada módulo
    ├── VolumeControl/
    ├── Thermal/
    ├── Battery/
    ├── CPU/
    ├── Screenshot/
    └── Clipboard/
```

### Añadir un nuevo módulo

1. Crea `Sources/Clutch/Modules/MiModulo/`
2. Implementa el protocolo `Module`:

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

3. Regístralo en `ClutchPopoverView.swift`:

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

## Licencia

[PolyForm Noncommercial License 1.0.0](LICENSE) — libre de usar, modificar y compartir para cualquier fin no comercial. El uso comercial requiere permiso del licenciante.
