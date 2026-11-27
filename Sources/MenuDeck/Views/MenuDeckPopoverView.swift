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
                if screen == .settings { login.refresh() }
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
    private static let moduleHeight: CGFloat = 260

    /// Two states, never both: the full set of tiles to choose from, or one
    /// module with the tiles folded into a strip above it. Twenty tiles in a
    /// grid are taller than any module, so keeping the grid up while one was
    /// open spent most of the panel on choices already made.
    private var mainPanel: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.08)

            if let id = expandedId,
               let mod = visibleModules.first(where: { $0.id == id }) {
                tileStrip
                Divider().opacity(0.08)
                moduleContent(mod)
            } else {
                tileGrid
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

    /// A constant height, not a maximum. With `.preferredContentSize` the
    /// popover tracks its content, so a per-module height made it resize on
    /// every switch — and again whenever anything inside a module appeared (the
    /// thermal log panel, the audio permission banner), which happens outside
    /// any animation transaction and reads as a jump.
    @ViewBuilder
    private func moduleContent(_ mod: any Module) -> some View {
        // makeContent() is type-erased, so every module lands in the same
        // structural slot and SwiftUI reuses the previous module's identity when
        // switching. onDisappear/onAppear then never fire, the new module's
        // manager is never start()ed, and the panel renders empty. Keying on the
        // module id forces a real teardown + setup per module.
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

    /// The one layout whose height never grows with the module count — and
    /// what every layout folds into while a module is open.
    private var rowTiles: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(visibleModules, id: \.id) { mod in
                        let isSelected = expandedId == mod.id
                        // The open module wears its name: with the grid folded
                        // away, nothing else on the panel says what it is.
                        ModuleIconTile(module: mod, isSelected: isSelected, showsName: isSelected) {
                            select(mod)
                        }
                        .frame(width: isSelected ? nil : 34)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            // A module opened by hot key, or from the far end of the grid,
            // would otherwise be selected somewhere off the edge of the strip.
            // Unwrapped on purpose: scrollTo matches ids by type as well as
            // value, and an Optional<String> never equals the tiles' String.
            .onAppear { if let id = expandedId { proxy.scrollTo(id, anchor: .center) } }
            .onChange(of: expandedId) { _, id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    /// The strip, with a way back to the full set in front of it. The row
    /// layout has no fuller view to go back to, so it gets the strip alone.
    private var tileStrip: some View {
        HStack(spacing: 0) {
            if tileLayout != .row {
                Button { expandedId = nil } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(Text("All modules"))
                .padding(.leading, 8)
            }
            rowTiles
        }
    }

    // MARK: – Settings panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.08)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("General")

                    SettingsGroup {
                        SettingsRow(label: "Default module", icon: "star") {
                            Picker("", selection: $defaultModuleId) {
                                Text("None").tag("")
                                // Only modules that are actually on the grid: opening
                                // onto a hidden module would show a panel with no tile.
                                ForEach(visibleModules, id: \.id) { mod in
                                    Label(mod.name, systemImage: mod.sfSymbol).tag(mod.id)
                                }
                            }
                        }

                        SettingsRow(label: "Layout", icon: "square.grid.2x2") {
                            Picker("", selection: $tileLayoutRaw) {
                                ForEach(TileLayout.allCases) { layout in
                                    Label(layout.label, systemImage: layout.sfSymbol)
                                        .tag(layout.rawValue)
                                }
                            }
                        }

                        SettingsRow(label: "Menu bar shows", icon: "menubar.rectangle") {
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

                    sectionLabel("Modules")
                        .padding(.top, 10)

                    SettingsGroup {
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

                    sectionLabel("Application")
                        .padding(.top, 10)

                    SettingsGroup {
                        SettingsRow(label: "Open at login", icon: "power") {
                            Toggle("", isOn: Binding(
                                get: { login.isEnabled },
                                set: { login.setEnabled($0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                        }

                        SettingsRow(label: "Version", icon: "info.circle") {
                            Text(Self.appVersion)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    loginNotes

                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit MenuDeck", systemImage: "power")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.top, 8)
                }
                .padding(12)
            }
            // The module list makes this panel taller than the screen would
            // like. A fixed height keeps the popover a stable size instead of
            // growing to fit twenty toggles.
            .frame(height: 380)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: Self.panelWidth)
    }

    // MARK: – Launch at login

    @ViewBuilder
    private var loginNotes: some View {
        if login.needsApproval {
            // The registration went through but macOS is holding it, so
            // nothing would actually start at login until it is approved.
            loginNote(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                text: Text("Waiting for approval in System Settings")
            ) {
                Button { login.openLoginItemsSettings() } label: {
                    Text("Open")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        } else if login.isEnabled && !login.isInApplications {
            loginNote(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                text: Text("This copy is not in /Applications, so login will break if it moves")
            ) { EmptyView() }
        } else if let error = login.lastError {
            loginNote(
                icon: "xmark.circle.fill",
                tint: .red,
                text: Text(error)
            ) { EmptyView() }
        }
    }

    private func loginNote<Trailing: View>(
        icon: String,
        tint: Color,
        text: Text,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(tint)
            text
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.horizontal, 10)
    }

    private static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.7)
            .padding(.leading, 10)
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

// MARK: – Settings rows

/// One rounded card of rows with hairlines between them — the same shape for
/// General, Modules and Application, so the screen reads as one list rather
/// than three different kinds of control.
private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { rows in
                ForEach(rows) { row in
                    row
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 33).opacity(0.06)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Same metrics as ModuleToggleRow, so every row on the screen lines up.
private struct SettingsRow<C: View>: View {
    let label: LocalizedStringKey
    let icon: String
    @ViewBuilder let control: () -> C

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Spacer(minLength: 6)
            // The control keeps its natural width; a squeezed menu button
            // truncates its own title ("Una…").
            control().fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
