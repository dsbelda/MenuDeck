import SwiftUI
import AppKit

struct MenuDeckPopoverView: View {
    @AppStorage("menudeck.defaultModuleId") private var defaultModuleId: String = ""
    @AppStorage("menudeck.menuBarMode")     private var menuBarMode:     String = "icon"
    /// Stores what the user turned *off*, not what they left on, so a module
    /// added in a later version shows up instead of staying invisible until
    /// they go looking for it.
    @AppStorage(ModuleRegistry.hiddenIDsKey) private var hiddenModuleIds:  String = ""
    @AppStorage("menudeck.tileLayout")       private var tileLayoutRaw:    String = TileLayout.grid.rawValue

    private var tileLayout: TileLayout {
        TileLayout(rawValue: tileLayoutRaw) ?? .grid
    }
    @ObservedObject private var state = PopoverState.shared

    private var expandedId: String? {
        get { state.expandedID }
        nonmutating set { state.expandedID = newValue }
    }

    private var screen: PopoverState.Screen {
        get { state.screen }
        nonmutating set { state.screen = newValue }
    }

    /// One source of truth for the popover width: the header, the tile grid
    /// and the settings list must agree or the panels jitter when switching.
    static let panelWidth: CGFloat = 284

    // MARK: – Enabled modules

    private var hiddenIds: Set<String> { ModuleRegistry.hiddenIDs }

    private var visibleModules: [any Module] { ModuleRegistry.visible }

    private func isEnabled(_ module: any Module) -> Bool {
        !hiddenIds.contains(module.id)
    }

    private func setEnabled(_ enabled: Bool, for module: any Module) {
        var hidden = hiddenIds
        if enabled { hidden.remove(module.id) } else { hidden.insert(module.id) }
        hiddenModuleIds = hidden.sorted().joined(separator: ",")
        module.setEnabled(enabled)

        guard !enabled else { return }
        // A hidden module must not stay expanded behind the settings screen,
        // and must not remain the module the popover opens on.
        if expandedId == module.id { expandedId = nil }
        if defaultModuleId == module.id { defaultModuleId = "" }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Also unanimated, and for the same reason as mainPanel: the two
            // panels are different heights, so while a transition ran the ZStack
            // sat at the taller of the two and the popover jumped to meet it.
            if screen == .main {
                mainPanel
            } else {
                settingsPanel
            }
        }
        .frame(width: Self.panelWidth)
        .background(.regularMaterial)
        .onAppear {
            if expandedId == nil,
               !defaultModuleId.isEmpty,
               !hiddenIds.contains(defaultModuleId) {
                expandedId = defaultModuleId
            }
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 10) {
            appIcon

            Text("MenuDeck")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            Spacer()

            // Settings / back button — icon morphs between states
            Button {
                screen = screen == .main ? .settings : .main
            } label: {
                Image(systemName: screen == .settings ? "chevron.left" : "gearshape.fill")
                    .font(.system(size: screen == .settings ? 11 : 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(.primary.opacity(0.07), in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            if screen == .main {
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.18, extraBounce: 0), value: screen)
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.62, green: 0.32, blue: 1.0),
                             Color(red: 0.40, green: 0.18, blue: 0.88)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 22, height: 22)
            MenuDeckGlyphView(color: .white)
                .frame(width: 11, height: 11)
        }
    }

    // MARK: – Main panel (tiles + expanded content)

    /// Tall enough for the dense modules (CPU cores, thermal sensors) without
    /// leaving too much empty glass under the short ones.
    private static let moduleHeight: CGFloat = 210

    private var mainPanel: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.08)

            tileGrid

            if let id = expandedId,
               let mod = visibleModules.first(where: { $0.id == id }) {
                Divider().opacity(0.08)
                ScrollView(.vertical) {
                    mod.makeContent()
                        // makeContent() is type-erased, so every module lands in
                        // the same structural slot and SwiftUI reuses the previous
                        // module's identity when switching. onDisappear/onAppear
                        // then never fire, the new module's manager is never
                        // start()ed, and the panel renders empty. Keying on the
                        // module id forces a real teardown + setup per module.
                        .id(mod.id)
                }
                // A constant height, not a maximum. With .preferredContentSize
                // the popover tracks its content, so a per-module height made
                // it resize on every switch — and again whenever anything
                // inside a module appeared (the thermal log panel, the audio
                // permission banner), which happens outside any animation
                // transaction and reads as a jump. Overflow now scrolls.
                .frame(height: Self.moduleHeight, alignment: .top)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        // Deliberately unanimated. Expanding a module changes the panel's
        // height, which the hosting controller pushes to the popover as a new
        // preferredContentSize. Animating it made SwiftUI publish a *series* of
        // intermediate heights, and the popover window chased each one a frame
        // behind — that lag is the jump you see on the first expand. Resizing in
        // a single layout pass keeps the window and its content in step.
        .frame(width: Self.panelWidth)
    }

    // MARK: – Tile grid  (4 columns, N rows)

    @ViewBuilder
    private var tileGrid: some View {
        if visibleModules.isEmpty {
            noModulesState
        } else {
            moduleTiles
        }
    }

    private var noModulesState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("Every module is turned off")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Turn some back on in Settings")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    /// No withAnimation anywhere in here: see the note on mainPanel. Each tile
    /// animates its own tint, which is the part that reads as feedback.
    private func select(_ module: any Module) {
        expandedId = expandedId == module.id ? nil : module.id
    }

    @ViewBuilder
    private var moduleTiles: some View {
        switch tileLayout {
        case .grid:  gridTiles(columns: TileLayout.grid.columns)
        case .icons: iconTiles(columns: TileLayout.icons.columns)
        case .list:  listTiles
        case .row:   rowTiles
        }
    }

    private func gridTiles(columns: Int) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(visibleModules, id: \.id) { mod in
                ModuleGridTile(module: mod, isSelected: expandedId == mod.id) {
                    select(mod)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func iconTiles(columns: Int) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)
        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(visibleModules, id: \.id) { mod in
                ModuleIconTile(module: mod, isSelected: expandedId == mod.id) {
                    select(mod)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var listTiles: some View {
        VStack(spacing: 1) {
            ForEach(visibleModules, id: \.id) { mod in
                ModuleListRow(module: mod, isSelected: expandedId == mod.id) {
                    select(mod)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    /// The one layout whose height never grows with the module count.
    private var rowTiles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(visibleModules, id: \.id) { mod in
                    ModuleIconTile(module: mod, isSelected: expandedId == mod.id) {
                        select(mod)
                    }
                    .frame(width: 34)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: – Settings panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.08)

            ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                sectionLabel("General")

                SettingsRow(label: "Default module", icon: "square.grid.2x2") {
                    Picker("", selection: $defaultModuleId) {
                        Text("None").tag("")
                        // Only modules that are actually on the grid: opening
                        // onto a hidden module would show a panel with no tile.
                        ForEach(visibleModules, id: \.id) { mod in
                            Label(mod.name, systemImage: mod.sfSymbol).tag(mod.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                }

                SettingsRow(label: "Layout", icon: "square.grid.2x2") {
                    Picker("", selection: $tileLayoutRaw) {
                        ForEach(TileLayout.allCases) { layout in
                            Label(layout.label, systemImage: layout.sfSymbol)
                                .tag(layout.rawValue)
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

                sectionLabel("Modules")

                VStack(spacing: 0) {
                    ForEach(ModuleRegistry.all, id: \.id) { mod in
                        ModuleToggleRow(
                            module: mod,
                            isEnabled: Binding(
                                get: { isEnabled(mod) },
                                set: { setEnabled($0, for: mod) }
                            )
                        )
                        if mod.id != ModuleRegistry.all.last?.id {
                            Divider().padding(.leading, 30).opacity(0.06)
                        }
                    }
                }
                .padding(.vertical, 2)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

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
            // The module list makes this panel taller than the screen would
            // like. A fixed height keeps the popover a stable size instead of
            // growing to fit twelve toggles.
            .frame(height: 380)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: Self.panelWidth)
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

// MARK: – Module enable/disable row

private struct ModuleToggleRow: View {
    let module: any Module
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: module.sfSymbol)
                .font(.system(size: 11, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isEnabled ? AnyShapeStyle(module.tintColor) : AnyShapeStyle(.tertiary))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(module.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                if let warning = module.requirementWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            ShortcutRecorder(moduleID: module.id, isEnabled: isEnabled)

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .tint(module.tintColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
