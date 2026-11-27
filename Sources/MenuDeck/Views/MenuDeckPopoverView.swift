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
    @ObservedObject private var login = LoginItemManager.shared

    private var expandedId: String? {
        get { state.expandedID }
        nonmutating set { state.expandedID = newValue }
    }

    private var screen: PopoverState.Screen {
        get { state.screen }
        nonmutating set { state.screen = newValue }
    }

    static let panelWidth: CGFloat = DeckMetrics.panelWidth

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
        HStack(spacing: 8) {
            if screen == .settings {
                DeckIconButton(
                    symbol: "chevron.left",
                    size: 24,
                    iconSize: 11,
                    weight: .semibold,
                    action: { screen = .main }
                )
                .help(Text("Back"))

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer()
            } else {
                appIcon

                Text("MenuDeck")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))

                Spacer()

                DeckIconButton(
                    symbol: "gearshape.fill",
                    size: 24,
                    iconSize: 11.5,
                    action: {
                        screen = .settings
                        login.refresh()
                    }
                )
                .help(Text("Settings"))

                DeckIconButton(
                    symbol: "power",
                    size: 24,
                    iconSize: 10.5,
                    weight: .semibold,
                    hoverTint: .red,
                    action: { NSApplication.shared.terminate(nil) }
                )
                .help(Text("Quit MenuDeck"))
            }
        }
        .padding(.horizontal, DeckMetrics.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .animation(.snappy(duration: 0.16, extraBounce: 0), value: screen)
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.64, green: 0.34, blue: 1.0),
                             Color(red: 0.42, green: 0.18, blue: 0.88)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                )
                .shadow(color: Color(red: 0.48, green: 0.22, blue: 0.92).opacity(0.28), radius: 3, y: 1)

            MenuDeckGlyphView(color: .white)
                .frame(width: 11, height: 11)
        }
    }

    // MARK: – Main panel (tiles + expanded content)

    private static let moduleHeight: CGFloat = DeckMetrics.moduleHeight

    /// Two states, never both: the full set of tiles to choose from, or one
    /// module with the tiles folded into a strip above it.
    private var mainPanel: some View {
        VStack(spacing: 0) {
            DeckHairline()

            if let id = expandedId,
               let mod = visibleModules.first(where: { $0.id == id }) {
                tileStrip
                DeckHairline()
                moduleContent(mod)
            } else {
                tileGrid
            }
        }
        // Deliberately unanimated so NSPopover resizes in a single layout pass.
        .frame(width: Self.panelWidth)
    }

    @ViewBuilder
    private func moduleContent(_ mod: any Module) -> some View {
        // Keying on the module id forces real teardown + setup per module so
        // whileShown() starts/stops each module cleanly.
        if mod.providesOwnScrolling {
            mod.makeContent()
                .id(mod.id)
                .frame(height: Self.moduleHeight, alignment: .top)
        } else {
            ScrollView(.vertical) {
                mod.makeContent().id(mod.id)
            }
            .frame(height: Self.moduleHeight, alignment: .top)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: – Tile grid

    @ViewBuilder
    private var tileGrid: some View {
        if visibleModules.isEmpty {
            DeckEmptyState(
                symbol: "square.grid.2x2",
                title: "Every module is turned off",
                subtitle: "Turn some back on in Settings",
                minHeight: 160
            )
        } else {
            moduleTiles
        }
    }

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
        let cols = Array(repeating: GridItem(.flexible(), spacing: 7), count: columns)
        return LazyVGrid(columns: cols, spacing: 7) {
            ForEach(visibleModules, id: \.id) { mod in
                ModuleGridTile(module: mod, isSelected: expandedId == mod.id) {
                    select(mod)
                }
            }
        }
        .padding(DeckMetrics.horizontalPadding)
    }

    private func iconTiles(columns: Int) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(visibleModules, id: \.id) { mod in
                ModuleIconTile(module: mod, isSelected: expandedId == mod.id) {
                    select(mod)
                }
            }
        }
        .padding(10)
    }

    private var listTiles: some View {
        ScrollView(.vertical) {
            VStack(spacing: 2) {
                ForEach(visibleModules, id: \.id) { mod in
                    ModuleListRow(module: mod, isSelected: expandedId == mod.id) {
                        select(mod)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 380)
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Horizontal strip of module tiles — used by the Row layout and as the
    /// folded switcher bar above any expanded module.
    private var rowTiles: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(visibleModules, id: \.id) { mod in
                        let isSelected = expandedId == mod.id
                        ModuleIconTile(
                            module: mod,
                            isSelected: isSelected,
                            showsName: isSelected,
                            compact: true
                        ) {
                            select(mod)
                        }
                        .frame(width: isSelected ? nil : 32)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .onAppear { if let id = expandedId { proxy.scrollTo(id, anchor: .center) } }
            .onChange(of: expandedId) { _, id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    /// The strip, with a return-to-grid button pinned at the leading edge.
    private var tileStrip: some View {
        HStack(spacing: 0) {
            if tileLayout != .row {
                DeckIconButton(
                    symbol: "square.grid.2x2",
                    size: 30,
                    iconSize: 12.5,
                    isCircular: false,
                    cornerRadius: 8,
                    action: { expandedId = nil }
                )
                .help(Text("All modules"))
                .padding(.leading, 8)
                .padding(.trailing, 6)

                Rectangle()
                    .fill(Color.primary.opacity(0.09))
                    .frame(width: 1, height: 18)
            }
            rowTiles
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.25), location: 0),
                            .init(color: .black, location: 0.03),
                            .init(color: .black, location: 0.94),
                            .init(color: .black.opacity(0.2), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }

    // MARK: – Settings panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckHairline()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    DeckSectionHeader("General")
                        .padding(.horizontal, 6)

                    DeckGroupedList(dividerInset: 36) {
                        SettingsRow(label: "Default module", icon: "star.fill", tint: .orange) {
                            Picker("", selection: $defaultModuleId) {
                                Text("None").tag("")
                                ForEach(visibleModules, id: \.id) { mod in
                                    Label(mod.name, systemImage: mod.sfSymbol).tag(mod.id)
                                }
                            }
                        }

                        SettingsRow(label: "Layout", icon: "square.grid.2x2.fill", tint: .blue) {
                            Picker("", selection: $tileLayoutRaw) {
                                ForEach(TileLayout.allCases) { layout in
                                    Label(layout.label, systemImage: layout.sfSymbol)
                                        .tag(layout.rawValue)
                                }
                            }
                        }

                        SettingsRow(label: "Menu bar shows", icon: "menubar.rectangle", tint: .purple) {
                            Picker("", selection: $menuBarMode) {
                                Label("App icon",     systemImage: "app").tag("icon")
                                Label("Temperature",  systemImage: "thermometer.medium").tag("temp")
                                Label("Battery",      systemImage: "battery.75").tag("battery")
                                Label("CPU",          systemImage: "cpu").tag("cpu")
                                Label("RAM",          systemImage: "memorychip").tag("memory")
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)

                    DeckSectionHeader("Modules")
                        .padding(.horizontal, 6)
                        .padding(.top, 8)

                    DeckGroupedList(dividerInset: 38) {
                        ForEach(ModuleRegistry.all, id: \.id) { mod in
                            ModuleToggleRow(
                                module: mod,
                                isEnabled: Binding(
                                    get: { isEnabled(mod) },
                                    set: { setEnabled($0, for: mod) }
                                )
                            )
                        }
                    }

                    DeckSectionHeader("Application")
                        .padding(.horizontal, 6)
                        .padding(.top, 8)

                    DeckGroupedList(dividerInset: 36) {
                        SettingsRow(label: "Open at login", icon: "power", tint: .green) {
                            Toggle("", isOn: Binding(
                                get: { login.isEnabled },
                                set: { login.setEnabled($0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                        }

                        SettingsRow(label: "Version", icon: "info.circle.fill", tint: .secondary) {
                            Text(Self.appVersion)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    loginNotes

                    DeckActionButton(
                        variant: .tinted(.red),
                        cornerRadius: 9,
                        verticalPadding: 8,
                        fullWidth: true
                    ) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit MenuDeck", systemImage: "power")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.top, 6)
                }
                .padding(DeckMetrics.horizontalPadding)
            }
            .frame(height: DeckMetrics.settingsHeight)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: Self.panelWidth)
    }

    // MARK: – Launch at login

    @ViewBuilder
    private var loginNotes: some View {
        if login.needsApproval {
            DeckStatusBanner(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: Text("Waiting for approval in System Settings")
            ) {
                Button { login.openLoginItemsSettings() } label: {
                    Text("Open")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        } else if login.isEnabled && !login.isInApplications {
            DeckStatusBanner(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: Text("This copy is not in /Applications, so login will break if it moves")
            )
        } else if let error = login.lastError {
            DeckStatusBanner(
                icon: "xmark.circle.fill",
                tint: .red,
                title: Text(error)
            )
        }
    }

    private static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
}

// MARK: – Module enable/disable row

private struct ModuleToggleRow: View {
    let module: any Module
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            DeckIconBadge(
                symbol: module.sfSymbol,
                tint: module.tintColor,
                size: 22,
                iconSize: 10.5,
                isActive: isEnabled,
                cornerRadius: 6
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(module.name)
                    .font(.system(size: 11.5, weight: .medium))
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

// MARK: – Settings row

private struct SettingsRow<C: View>: View {
    let label: LocalizedStringKey
    let icon: String
    var tint: Color = .secondary
    @ViewBuilder let control: () -> C

    var body: some View {
        HStack(spacing: 8) {
            DeckIconBadge(
                symbol: icon,
                tint: tint,
                size: 20,
                iconSize: 10,
                isActive: tint != .secondary,
                cornerRadius: 5.5
            )
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Spacer(minLength: 6)
            control().fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
