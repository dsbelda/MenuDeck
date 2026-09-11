import AppKit
import SwiftUI

struct BrewView: View {
    @ObservedObject private var mgr = BrewManager.shared
    @State private var tab: Tab = .outdated
    @State private var pendingRemoval: String?
    @State private var didCopyInstall = false

    private enum Tab: Hashable { case outdated, installed }

    var body: some View {
        Group {
            switch mgr.availability {
            case .checking:  ProgressView().controlSize(.small).padding(.vertical, 30)
            case .missing:   missingState
            case .found:     content
            }
        }
        .onAppear { mgr.load() }
    }

    // MARK: – Not installed

    private var missingState: some View {
        VStack(spacing: 9) {
            Image(systemName: "mug")
                .font(.system(size: 26, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)

            Text("Homebrew not found")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text("This module needs Homebrew installed. Looked in /opt/homebrew and /usr/local.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            HStack(spacing: 6) {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                } label: {
                    Text("Open brew.sh")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                // The install command is a curl piped into bash. Handing it over
                // for the user to read and run in their own terminal is the only
                // honest way to offer it — a menu bar app must not run that
                // silently on their behalf.
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.installCommand, forType: .string)
                    didCopyInstall = true
                } label: {
                    Text(didCopyInstall ? "Copied" : "Copy install command")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private static let installCommand =
        #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#

    // MARK: – Main

    @ViewBuilder
    private var content: some View {
        if let job = mgr.job {
            jobPanel(job)
        } else {
            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.08)
                packageList
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Picker("", selection: $tab) {
                Text("\(mgr.outdated.count) outdated").tag(Tab.outdated)
                Text("\(mgr.requested.count) installed").tag(Tab.installed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            Button {
                mgr.load(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(mgr.isLoading)
            .help("Reload the installed list")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var packageList: some View {
        let items = tab == .outdated ? mgr.outdated : mgr.requested

        if mgr.isLoading && mgr.packages.isEmpty {
            ProgressView().controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        } else if items.isEmpty {
            Text(tab == .outdated ? "Everything is up to date" : "Nothing installed")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        } else {
            VStack(spacing: 0) {
                if tab == .outdated {
                    upgradeAllRow
                    Divider().opacity(0.07)
                }
                ForEach(items) { package in
                    PackageRow(
                        package: package,
                        isPendingRemoval: pendingRemoval == package.id,
                        onUpgrade: { mgr.upgrade(package) },
                        onRequestRemoval: { pendingRemoval = package.id },
                        onCancelRemoval: { pendingRemoval = nil },
                        onConfirmRemoval: {
                            pendingRemoval = nil
                            mgr.uninstall(package)
                        }
                    )
                    if package.id != items.last?.id {
                        Divider().padding(.leading, 12).opacity(0.06)
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private var upgradeAllRow: some View {
        HStack(spacing: 8) {
            Button {
                mgr.upgradeAll()
            } label: {
                Label("Upgrade all", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                mgr.updateIndex()
            } label: {
                Text("Update index")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Runs brew update to refresh the package index")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: – Running job

    private func jobPanel(_ job: BrewManager.Job) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if job.isFinished {
                    Image(systemName: job.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(job.succeeded ? Color.green : Color.orange)
                } else {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                }

                Text(job.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                if job.isFinished {
                    Button { mgr.dismissJob() } label: {
                        Text("Done")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().opacity(0.08)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(job.output.isEmpty ? "…" : job.output)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .id("output")
                }
                .frame(height: 118)
                .onChange(of: job.output) { _, _ in
                    proxy.scrollTo("output", anchor: .bottom)
                }
            }

            if job.isFinished && !job.succeeded {
                Divider().opacity(0.08)
                failureFooter(job)
            }
        }
    }

    /// Casks with a pkg installer need an admin password, which a popover has no
    /// safe way to collect — so a failure hands the command over to Terminal
    /// rather than trying to prompt.
    private func failureFooter(_ job: BrewManager.Job) -> some View {
        HStack(spacing: 8) {
            Text("Some packages need admin rights")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(job.command, forType: .string)
            } label: {
                Label("Copy command", systemImage: "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: – Row

private struct PackageRow: View {
    let package: BrewManager.Package
    let isPendingRemoval: Bool
    let onUpgrade: () -> Void
    let onRequestRemoval: () -> Void
    let onCancelRemoval: () -> Void
    let onConfirmRemoval: () -> Void

    @State private var isHovered = false

    var body: some View {
        Group {
            if isPendingRemoval {
                removalConfirmation
            } else {
                normalRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered && !isPendingRemoval ? Color.primary.opacity(0.04) : .clear)
        .onHover { isHovered = $0 }
    }

    private var normalRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(package.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    if package.isCask {
                        Text("cask")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 3))
                    }
                    if package.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(versionLine)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(package.isOutdated
                        ? AnyShapeStyle(Color.orange)
                        : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if isHovered {
                if package.isOutdated && !package.isPinned {
                    iconButton("arrow.up.circle", tint: .orange, help: "Upgrade", action: onUpgrade)
                }
                iconButton("trash", tint: .secondary, help: "Uninstall", action: onRequestRemoval)
            }
        }
    }

    private var versionLine: String {
        package.isOutdated
            ? "\(package.installedVersion) → \(package.latestVersion)"
            : package.installedVersion
    }

    private var removalConfirmation: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Uninstall \(package.name)?")
                .font(.system(size: 11, weight: .semibold))

            if !package.dependents.isEmpty {
                // brew will refuse the uninstall in this case; saying so up
                // front beats letting the command fail with a wall of text.
                Label(
                    "\(package.dependents.count) installed packages depend on it",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 9))
                .foregroundStyle(.orange)
                .lineLimit(1)
            }

            HStack(spacing: 6) {
                Button("Cancel", action: onCancelRemoval)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Button("Uninstall", action: onConfirmRemoval)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func iconButton(
        _ symbol: String,
        tint: Color,
        help: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
