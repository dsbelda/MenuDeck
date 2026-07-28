import SwiftUI
import AppKit

// Module instances live at file scope so state persists between popover open/close cycles.
@MainActor
private let allModules: [any Module] = [
    VolumeControlModule(),
    ThermalModule(),
    BatteryModule(),
    CPUModule(),
    FPSModule(),
    NetworkModule(),
    CaffeineModule(),
    ScreenshotModule(),
    ClipboardModule(),
]

struct MenuDeckPopoverView: View {
    @AppStorage("menudeck.defaultModuleId") private var defaultModuleId: String = ""
    @AppStorage("menudeck.menuBarMode")     private var menuBarMode:     String = "icon"
    @State private var expandedId: String? = nil
    @State private var screen: Screen = .main

    enum Screen { case main, settings }

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .top) {
                if screen == .main {
                    mainPanel
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal:   .move(edge: .leading)
                        ))
                } else {
                    settingsPanel
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal:   .move(edge: .trailing)
                        ))
                }
            }
            .clipped()
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: screen)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear {
            if expandedId == nil, !defaultModuleId.isEmpty {
                expandedId = defaultModuleId
            }
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 10) {
            appIcon

            Text("MenuDeck")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Spacer()

            // Settings / back button — icon morphs between states
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    screen = screen == .main ? .settings : .main
                }
            } label: {
                Image(systemName: screen == .settings ? "chevron.left" : "gearshape.fill")
                    .font(.system(size: screen == .settings ? 12 : 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.primary.opacity(0.07), in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            if screen == .main {
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: screen)
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.62, green: 0.32, blue: 1.0),
                             Color(red: 0.40, green: 0.18, blue: 0.88)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 30, height: 30)
                .shadow(color: .purple.opacity(0.35), radius: 6, y: 2)
            MenuDeckGlyphView(color: .white)
                .frame(width: 14, height: 14)
        }
    }

    // MARK: – Main panel (tiles + expanded content)

    /// Tall enough for the dense modules (CPU cores, thermal sensors) without
    /// leaving too much empty glass under the short ones.
    private static let moduleHeight: CGFloat = 250

    private var mainPanel: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.08)

            tileGrid

            if let id = expandedId,
               let mod = allModules.first(where: { $0.id == id }) {
                Divider().opacity(0.08)
                ScrollView(.vertical) {
                    mod.makeContent()
                }
                // A constant height, not a maximum. With .preferredContentSize
                // the popover tracks its content, so a per-module height made
                // it resize on every switch — and again whenever anything
                // inside a module appeared (the thermal log panel, the audio
                // permission banner), which happens outside any animation
                // transaction and reads as a jump. Overflow now scrolls.
                .frame(height: Self.moduleHeight, alignment: .top)
                .scrollBounceBehavior(.basedOnSize)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: expandedId)
        .frame(width: 320)
    }

    // MARK: – Tile grid  (3 columns, N rows)

    private var tileGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)
        return LazyVGrid(columns: cols, spacing: 9) {
            ForEach(allModules, id: \.id) { mod in
                ModuleTile(
                    module: mod,
                    isSelected: expandedId == mod.id
                ) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                        expandedId = expandedId == mod.id ? nil : mod.id
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: – Settings panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.08)

            VStack(alignment: .leading, spacing: 18) {
                sectionLabel("General")

                SettingsRow(label: "Default module", icon: "square.grid.2x2") {
                    Picker("", selection: $defaultModuleId) {
                        Text("None").tag("")
                        ForEach(allModules, id: \.id) { mod in
                            Label(mod.name, systemImage: mod.sfSymbol).tag(mod.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                }

                SettingsRow(label: "Menu bar shows", icon: "menubar.rectangle") {
                    Picker("", selection: $menuBarMode) {
                        Label("App icon",     systemImage: "hand.grip").tag("icon")
                        Label("Temperature",  systemImage: "thermometer.medium").tag("temp")
                        Label("Battery",      systemImage: "battery.75").tag("battery")
                        Label("CPU",          systemImage: "cpu").tag("cpu")
                        Label("RAM",          systemImage: "memorychip").tag("memory")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                }

                Divider().opacity(0.07)

                sectionLabel("Application")

                HStack {
                    Text("Version")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.appVersion)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 2)

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit MenuDeck", systemImage: "power")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(16)
        }
        .frame(width: 320)
    }

    private static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.7)
    }
}

// MARK: – Module Tile

private struct ModuleTile: View {
    let module: any Module
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: module.sfSymbol)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : module.tintColor)
                    .frame(height: 28)
                    .contentTransition(.symbolEffect(.replace))

                Text(module.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.88) : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(module.tintColor.gradient) : AnyShapeStyle(.primary.opacity(0.06)))
                    .shadow(color: isSelected ? module.tintColor.opacity(0.38) : .clear,
                            radius: 8, y: 3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(module.tintColor.opacity(isSelected ? 0 : 0.22), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isSelected)
    }
}

// MARK: – Settings Row helper

private struct SettingsRow<C: View>: View {
    let label: LocalizedStringKey
    let icon: String
    @ViewBuilder let control: () -> C

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
