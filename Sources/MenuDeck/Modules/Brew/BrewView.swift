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
            case .checking:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                missingState
            case .found:
                content
            }
        }
        .onAppear { mgr.load() }
    }

    // MARK: – Not installed

    private var missingState: some View {
        DeckEmptyState(
            symbol: "mug",
            tint: .orange,
            title: "Homebrew not found",
            subtitle: "This module needs Homebrew installed. Looked in /opt/homebrew and /usr/local.",
            minHeight: DeckMetrics.moduleHeight - 20
        ) {
            HStack(spacing: 6) {
                DeckActionButton(
                    variant: .tinted(.orange),
                    cornerRadius: 16,
                    horizontalPadding: 10,
                    verticalPadding: 5
                ) {
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                } label: {
                    Text("Open brew.sh")
                        .font(.system(size: 10, weight: .semibold))
                }

                DeckActionButton(
                    variant: .neutral,
                    cornerRadius: 16,
                    horizontalPadding: 10,
                    verticalPadding: 5
                ) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.installCommand, forType: .string)
                    didCopyInstall = true
                } label: {
                    Text(didCopyInstall ? "Copied" : "Copy install command")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
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
                DeckHairline()
                packageList
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 7) {
            DeckSegmentedPicker(
                selection: $tab,
                segments: [
                    .init(id: .outdated, title: String(localized: "\(mgr.outdated.count) outdated")),
                    .init(id: .installed, title: String(localized: "\(mgr.requested.count) installed")),
                ]
            )

            DeckIconButton(
                symbol: "arrow.clockwise",
                size: 22,
                iconSize: 10,
                weight: .semibold,
                action: { mgr.load(force: true) }
            )
            .disabled(mgr.isLoading)
            .opacity(mgr.isLoading ? 0.45 : 1)
            .help("Reload the installed list")
        }
        .padding(.horizontal, DeckMetrics.horizontalPadding)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var packageList: some View {
        let items = tab == .outdated ? mgr.outdated : mgr.requested

        if mgr.isLoading && mgr.packages.isEmpty {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            DeckEmptyState(
                symbol: tab == .outdated ? "checkmark.seal" : "mug",
                tint: tab == .outdated ? .green : .orange,
                title: tab == .outdated ? "Everything is up to date" : "Nothing installed",
                minHeight: 200
            )
        } else {
            VStack(spacing: 0) {
                if tab == .outdated {
                    upgradeAllRow
                    DeckHairline()
                }

                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
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
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var upgradeAllRow: some View {
        HStack(spacing: 8) {
            DeckActionButton(
                variant: .tinted(.orange),
                cornerRadius: 7,
                horizontalPadding: 9,
                verticalPadding: 4
            ) {
                mgr.upgradeAll()
            } label: {
                Label("Upgrade all", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 10.5, weight: .semibold))
            }

            Spacer()

            DeckActionButton(
                variant: .neutral,
                cornerRadius: 7,
                horizontalPadding: 8,
                verticalPadding: 4
            ) {
                mgr.updateIndex()
            } label: {
                Text("Update index")
                    .font(.system(size: 10, weight: .medium))
            }
            .help("Runs brew update to refresh the package index")
        }
        .padding(.horizontal, DeckMetrics.horizontalPadding)
        .padding(.vertical, 7)
    }

    // MARK: – Running job

    private func jobPanel(_ job: BrewManager.Job) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if job.isFinished {
                    Image(systemName: job.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(job.succeeded ? Color.green : Color.orange)
                } else {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                }

                Text(job.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                if job.isFinished {
                    DeckActionButton(
                        variant: .tinted(.orange),
                        cornerRadius: 7,
                        horizontalPadding: 9,
                        verticalPadding: 4
                    ) {
                        mgr.dismissJob()
                    } label: {
                        Text("Done")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                }
            }
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.vertical, 9)

            DeckHairline()

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(job.output.isEmpty ? "…" : job.output)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("output")
                }
                .background(
                    Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                )
                .padding(DeckMetrics.horizontalPadding)
                .onChange(of: job.output) { _, _ in
                    proxy.scrollTo("output", anchor: .bottom)
                }
            }

            if job.isFinished && !job.succeeded {
                failureFooter(job)
                    .padding(.horizontal, DeckMetrics.horizontalPadding)
                    .padding(.bottom, 10)
            }
        }
    }

    private func failureFooter(_ job: BrewManager.Job) -> some View {
        DeckStatusBanner(
            icon: "lock.fill",
            tint: .orange,
            title: Text("Some packages need admin rights")
        ) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(job.command, forType: .string)
            } label: {
                Label("Copy command", systemImage: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
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

    var body: some View {
        if isPendingRemoval {
            removalConfirmation
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
        } else {
            DeckHoverRow(horizontalPadding: 9, verticalPadding: 6, horizontalInset: 6) { isHovered in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(package.name)
                                .font(.system(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                            if package.isCask {
                                Text("cask")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.08), in: Capsule())
                            }
                            if package.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 7.5))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Text(versionLine)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(package.isOutdated
                                ? AnyShapeStyle(Color.orange)
                                : AnyShapeStyle(.tertiary))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if isHovered {
                        HStack(spacing: 4) {
                            if package.isOutdated && !package.isPinned {
                                DeckIconButton(
                                    symbol: "arrow.up.circle.fill",
                                    size: 22,
                                    iconSize: 12,
                                    tint: .orange,
                                    hoverTint: .orange,
                                    action: onUpgrade
                                )
                                .help("Upgrade")
                            }
                            DeckIconButton(
                                symbol: "trash",
                                size: 22,
                                iconSize: 10.5,
                                hoverTint: .red,
                                action: onRequestRemoval
                            )
                            .help("Uninstall")
                        }
                    }
                }
            }
        }
    }

    private var versionLine: String {
        package.isOutdated
            ? "\(package.installedVersion) → \(package.latestVersion)"
            : package.installedVersion
    }

    private var removalConfirmation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Uninstall \(package.name)?")
                .font(.system(size: 11, weight: .semibold))

            if !package.dependents.isEmpty {
                Label(
                    "\(package.dependents.count) installed packages depend on it",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 9.5))
                .foregroundStyle(.orange)
                .lineLimit(1)
            }

            HStack(spacing: 6) {
                DeckActionButton(
                    variant: .neutral,
                    cornerRadius: 6,
                    horizontalPadding: 9,
                    verticalPadding: 4,
                    action: onCancelRemoval
                ) {
                    Text("Cancel").font(.system(size: 10, weight: .medium))
                }

                DeckActionButton(
                    variant: .solid(.red),
                    cornerRadius: 6,
                    horizontalPadding: 9,
                    verticalPadding: 4,
                    action: onConfirmRemoval
                ) {
                    Text("Uninstall").font(.system(size: 10, weight: .semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.red.opacity(0.20), lineWidth: 0.5)
        )
    }
}
