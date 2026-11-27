import AppKit
import SwiftUI

struct UninstallerView: View {
    @StateObject private var mgr = UninstallerManager()
    @State private var query = ""

    var body: some View {
        Group {
            switch mgr.stage {
            case .list:                       appList
            case .inspecting(let app):        inspector(app)
            case .removing(let app):          removing(app)
            case .done(let app, let n, let f): summary(app, moved: n, failed: f)
            }
        }
        .onAppear { mgr.loadApps() }
    }

    // MARK: – App list

    private var filtered: [UninstallerManager.App] {
        guard !query.isEmpty else { return mgr.apps }
        return mgr.apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            filterBar
            DeckHairline()

            if mgr.isLoadingApps {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                DeckEmptyState(
                    symbol: "magnifyingglass",
                    tint: .secondary,
                    title: "No apps match “\(query)”",
                    minHeight: 200
                )
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { app in
                            appRow(app)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Filter apps", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))

            if query.isEmpty {
                Text("\(mgr.apps.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            } else {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, DeckMetrics.horizontalPadding)
        .padding(.vertical, 8)
    }

    private func appRow(_ app: UninstallerManager.App) -> some View {
        Button { mgr.inspect(app) } label: {
            DeckHoverRow(horizontalPadding: 8, verticalPadding: 6, horizontalInset: 6) { isHovered in
                HStack(spacing: 9) {
                    AppIcon(path: app.url.path, size: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let version = app.version {
                            Text(version)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(isHovered ? .secondary : .tertiary)
                }
            }
        }
        .buttonStyle(DeckPressStyle(scale: 0.985))
    }

    // MARK: – Inspector

    private func inspector(_ app: UninstallerManager.App) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                DeckIconButton(
                    symbol: "chevron.left",
                    size: 22,
                    iconSize: 10,
                    weight: .semibold,
                    action: { mgr.backToList() }
                )

                AppIcon(path: app.url.path, size: 20)

                Text(app.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(formatBytes(mgr.selectedBytes))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.red.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.vertical, 8)

            DeckHairline()

            if mgr.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 8) {
                        warnings(app)
                        itemList(app)
                    }
                    .padding(DeckMetrics.horizontalPadding)
                }
                .scrollBounceBehavior(.basedOnSize)

                actionBar(app)
            }
        }
    }

    @ViewBuilder
    private func warnings(_ app: UninstallerManager.App) -> some View {
        if let running = mgr.runningInstance(of: app) {
            DeckStatusBanner(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: Text("\(app.name) is running")
            ) {
                Button { running.terminate() } label: {
                    Text("Quit it")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }

        if let token = app.caskToken {
            DeckStatusBanner(
                icon: "mug.fill",
                tint: .orange,
                title: Text("Installed with Homebrew — use brew uninstall --cask \(token)")
            )
        }

        if mgr.scanIncomplete {
            DeckStatusBanner(
                icon: "lock.fill",
                tint: .secondary,
                title: Text("Some folders need Full Disk Access, so this list may be short")
            )
        }
    }

    private func itemList(_ app: UninstallerManager.App) -> some View {
        DeckGroupedList(dividerInset: 30) {
            bundleRow(app)
            ForEach(mgr.leftovers) { leftover in
                leftoverRow(leftover)
            }
        }
    }

    private func bundleRow(_ app: UninstallerManager.App) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.red)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.url.lastPathComponent)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                Text("The app itself")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text(formatBytes(mgr.bundleBytes))
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func leftoverRow(_ leftover: UninstallerManager.Leftover) -> some View {
        let isOn = mgr.selection.contains(leftover.id)
        return Button { mgr.toggle(leftover) } label: {
            DeckHoverRow(horizontalPadding: 10, verticalPadding: 6, horizontalInset: 0) { _ in
                HStack(spacing: 8) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.system(size: 12))
                        .foregroundStyle(isOn ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary))

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(leftover.displayName)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isOn ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 4) {
                            Text(leftover.category)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            if leftover.match == .appName {
                                Text("name match")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 0.5)
                                    .background(Color.orange.opacity(0.13), in: Capsule())
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    Text(formatBytes(leftover.bytes))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func actionBar(_ app: UninstallerManager.App) -> some View {
        let isRunning = mgr.runningInstance(of: app) != nil
        return VStack(spacing: 5) {
            DeckHairline()

            DeckActionButton(
                variant: .solid(.red),
                cornerRadius: 9,
                verticalPadding: 8,
                fullWidth: true
            ) {
                mgr.uninstall(app)
            } label: {
                Label("Move to Trash", systemImage: "trash")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .disabled(isRunning)
            .opacity(isRunning ? 0.4 : 1)
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.top, 4)

            Text("Nothing is deleted — everything goes to the Trash")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }

    // MARK: – Removing / done

    private func removing(_ app: UninstallerManager.App) -> some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Moving \(app.name) to the Trash…")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summary(
        _ app: UninstallerManager.App, moved: Int, failed: [String]
    ) -> some View {
        DeckEmptyState(
            symbol: failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            tint: failed.isEmpty ? .green : .orange,
            title: failed.isEmpty
                ? "Moved \(moved) items to the Trash"
                : "Could not move some items",
            minHeight: 220
        ) {
            VStack(spacing: 8) {
                if !failed.isEmpty {
                    Text(failed.prefix(3).joined(separator: ", "))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                DeckActionButton(
                    variant: .tinted(.red),
                    cornerRadius: 16,
                    horizontalPadding: 14,
                    verticalPadding: 5
                ) {
                    mgr.backToList()
                } label: {
                    Text("Done")
                        .font(.system(size: 10.5, weight: .semibold))
                }
            }
        }
    }
}
