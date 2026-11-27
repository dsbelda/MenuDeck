# MenuDeck

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
| **Volumen** | Sliders de volumen y silencio por aplicación vía CoreAudio HAL |
| **Salida** | Cambia el dispositivo de salida de audio |
| **Temperatura** | Temperaturas de los sensores en vivo vía SMC |
| **Batería** | Carga, salud, ciclos y tiempo de pantalla |
| **CPU / RAM** | Uso por núcleo y desglose de memoria |
| **Disco** | Espacio libre de cada volumen montado |
| **FPS** | Uso de GPU y el HUD de Metal del sistema |
| **Red** | Velocidad, IP local y señal Wi-Fi |
| **Despierto** | Mantiene el Mac y la pantalla activos, con temporizador opcional |
| **Capturas** | Captura de pantalla completa, área o ventana |
| **Portapapeles** | Historial del portapapeles |
| **Color** | Cuentagotas de pantalla con historial |
| **Desarrollo** | Acceso rápido a tu terminal, editores y agentes de programación |
| **Brew** | Paquetes de Homebrew instalados y pendientes de actualizar |
| **Puertos** | Puertos TCP a la escucha, y parar lo que los ocupa |
| **Atajos** | Ejecuta Atajos desde la barra de menú |
| **Bluetooth** | Conecta y desconecta dispositivos emparejados |
| **Papelera** | Tamaño de la Papelera y vaciado |
| **Desinstalar** | Elimina una app junto con los archivos que deja |
| **Finder** | Archivos ocultos, barra de ruta, barra de estado e iconos del escritorio |

Cada módulo se puede desactivar en Ajustes y tener un atajo de teclado global.

---

## Requisitos

- macOS 26 (Tahoe) o posterior
- Xcode Command Line Tools (provee `swift`):
  ```bash
  xcode-select --install
  ```

## Cómo ejecutarlo

MenuDeck es un proyecto de Swift Package Manager gestionado con un `Makefile`. Debe ejecutarse como un `.app` firmado (no el binario en crudo) — de lo contrario macOS no concede ni conserva permisos TCC como el de Audio Capture.

### Ejecutar en desarrollo

```bash
make run
```

Esto compila un binario de depuración, lo empaqueta en `MenuDeck.app`, lo firma ad-hoc, mata cualquier instancia en ejecución y lo vuelve a abrir.

### Compilar un bundle .app de release

```bash
make app
```

Crea `MenuDeck.app` en la carpeta del proyecto (configuración release).

### Instalar en /Applications

```bash
make install
```

Copia el bundle de release a `/Applications/MenuDeck.app`. Para que se abra automáticamente al iniciar sesión: **Ajustes del Sistema → General → Elementos de inicio de sesión → añadir MenuDeck**.

### Limpiar artefactos de compilación

```bash
make clean
```

Elimina `.build/` y `MenuDeck.app`.

---

## Arquitectura

```
Sources/MenuDeck/
├── main.swift                    # Punto de entrada de NSApplication
├── AppDelegate.swift             # App sin icono en el Dock, arranque y cierre
├── MenuBar/
│   └── MenuBarController.swift   # NSStatusItem + NSPopover, atajos globales
├── Views/
│   ├── MenuDeckPopoverView.swift # Vista raíz de SwiftUI (teselas + ajustes)
│   ├── PopoverState.swift        # Módulo visible y el modificador whileShown
│   └── TileLayout.swift          # Disposiciones: cuadrícula, iconos, lista, fila
├── Support/                      # Shell, atajos, inicio de sesión, temporizadores
└── Modules/
    ├── Module.swift              # Protocolo que implementa cada módulo
    ├── ModuleRegistry.swift      # La lista de módulos y cuáles están activos
    └── <Nombre>/                 # Una carpeta por módulo: Module, Manager, View
```

### Añadir un nuevo módulo

1. Crea `Sources/MenuDeck/Modules/MiModulo/`
2. Implementa el protocolo `Module`:

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

3. Regístralo en `Modules/ModuleRegistry.swift`:

```swift
static let all: [any Module] = [
    VolumeControlModule(),
    // …
    MyModule(),
]
```

Si el módulo sondea o anima, arráncalo y páralo con `.whileShown(start, stop:)` en lugar de
`onAppear`/`onDisappear`: cerrar el popover no desmonta el árbol de SwiftUI, así que esos nunca se
disparan y el módulo seguiría trabajando con el popover cerrado.

---

## Licencia

[PolyForm Noncommercial License 1.0.0](LICENSE) — libre de usar, modificar y compartir para cualquier fin no comercial. El uso comercial requiere permiso del licenciante.
