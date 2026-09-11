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
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                TextField("Search apps", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.08)

            if mgr.isLoadingApps {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ForEach(filtered) { app in
                    appRow(app)
                    if app.id != filtered.last?.id {
                        Divider().padding(.leading, 38).opacity(0.06)
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func appRow(_ app: UninstallerManager.App) -> some View {
        Button { mgr.inspect(app) } label: {
            HStack(spacing: 9) {
                AppIcon(path: app.url.path, size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    if let version = app.version {
                        Text(version)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: – Inspector

    private func inspector(_ app: UninstallerManager.App) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { mgr.backToList() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                AppIcon(path: app.url.path, size: 18)

                Text(app.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(formatBytes(mgr.selectedBytes))
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.08)

            if mgr.isScanning {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity).padding(.vertical, 26)
            } else {
                warnings(app)
                itemList(app)
                actionBar(app)
            }
        }
    }

    @ViewBuilder
    private func warnings(_ app: UninstallerManager.App) -> some View {
        if let running = mgr.runningInstance(of: app) {
            banner(icon: "exclamationmark.triangle.fill", tint: .orange) {
                HStack(spacing: 6) {
                    Text("\(app.name) is running")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { running.terminate() } label: {
                        Text("Quit it")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if let token = app.caskToken {
            // Trashing the bundle would leave Homebrew still believing the cask
            // is installed, and its next upgrade would fail confusingly.
            banner(icon: "mug.fill", tint: .orange) {
                Text("Installed with Homebrew — use brew uninstall --cask \(token)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if mgr.scanIncomplete {
            banner(icon: "lock.fill", tint: .secondary) {
                Text("Some folders need Full Disk Access, so this list may be short")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func banner<C: View>(
        icon: String, tint: Color, @ViewBuilder content: () -> C
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(tint.opacity(0.07))
    }

    private func itemList(_ app: UninstallerManager.App) -> some View {
        VStack(spacing: 0) {
            bundleRow(app)
            ForEach(mgr.leftovers) { leftover in
                Divider().padding(.leading, 30).opacity(0.06)
                leftoverRow(leftover)
            }
        }
    }

    private func bundleRow(_ app: UninstallerManager.App) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.red)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.url.lastPathComponent)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text("The app itself")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Text(formatBytes(mgr.bundleBytes))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func leftoverRow(_ leftover: UninstallerManager.Leftover) -> some View {
        let isOn = mgr.selection.contains(leftover.id)
        return Button { mgr.toggle(leftover) } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11))
                    .foregroundStyle(isOn ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary))

                VStack(alignment: .leading, spacing: 1) {
                    Text(leftover.displayName)
                        .font(.system(size: 10))
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
                                .padding(.horizontal, 3)
                                .padding(.vertical, 0.5)
                                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                Spacer(minLength: 4)

                Text(formatBytes(leftover.bytes))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionBar(_ app: UninstallerManager.App) -> some View {
        VStack(spacing: 6) {
            Divider().opacity(0.08)
            Button { mgr.uninstall(app) } label: {
                Label("Move to Trash", systemImage: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(mgr.runningInstance(of: app) != nil)
            .opacity(mgr.runningInstance(of: app) != nil ? 0.4 : 1)
            .padding(.horizontal, 12)

            Text("Nothing is deleted — everything goes to the Trash")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }

    // MARK: – Removing / done

    private func removing(_ app: UninstallerManager.App) -> some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Moving \(app.name) to the Trash…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private func summary(
        _ app: UninstallerManager.App, moved: Int, failed: [String]
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(failed.isEmpty ? Color.green : Color.orange)

            Text(failed.isEmpty
                 ? "Moved \(moved) items to the Trash"
                 : "Could not move some items")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !failed.isEmpty {
                Text(failed.prefix(3).joined(separator: ", "))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }

            Button { mgr.backToList() } label: {
                Text("Done")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

// MARK: – Icon

/// NSWorkspace hits the disk for each icon, so they are resolved once and kept
/// for the life of the popover rather than looked up on every row redraw.
private struct AppIcon: View {
    let path: String
    let size: CGFloat

    @MainActor private static var cache: [String: NSImage] = [:]

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: size, height: size)
    }

    private var icon: NSImage {
        if let cached = Self.cache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        Self.cache[path] = image
        return image
    }
}
