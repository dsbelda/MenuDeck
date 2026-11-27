import SwiftUI

struct DevAppsView: View {
    @StateObject private var mgr = DevAppsManager()
    @AppStorage("menudeck.devTab") private var tab: Tab = .apps
    @AppStorage("menudeck.devProjectApp") private var openerID = ""

    private enum Tab: String { case apps, projects }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            DeckSegmentedPicker(
                selection: $tab,
                segments: [
                    .init(id: .apps, title: String(localized: "Apps")),
                    .init(id: .projects, title: String(localized: "Projects")),
                ]
            )
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.top, 9)
            .padding(.bottom, 8)

            DeckHairline()

            switch tab {
            case .apps:     appGrid
            case .projects: projectList
            }
        }
        .whileShown { mgr.refresh() }
    }

    // MARK: – Apps

    private var appGrid: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(mgr.apps) { app in
                        DevAppTile(name: app.name) {
                            AppIcon(path: app.url.path, size: 30)
                        } action: {
                            mgr.open(app)
                        }
                        .contextMenu {
                            Button("Remove", role: .destructive) { mgr.remove(app) }
                        }
                    }

                    DevAppTile(name: String(localized: "Add"), isDashed: true) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } action: {
                        mgr.pickApps()
                    }
                }

                if !mgr.apps.isEmpty {
                    Text("Right-click an app to remove it")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DeckMetrics.horizontalPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: – Projects

    private var opener: DevAppsManager.App? {
        mgr.apps.first { $0.bundleID == openerID } ?? mgr.apps.first
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if let opener {
                    Text("Open with")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { opener.bundleID },
                        set: { openerID = $0 }
                    )) {
                        ForEach(mgr.apps) { app in
                            Text(app.name).tag(app.bundleID)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                }

                Spacer(minLength: 4)

                DeckActionButton(
                    variant: .neutral,
                    cornerRadius: 7,
                    horizontalPadding: 7,
                    verticalPadding: 4
                ) {
                    mgr.chooseProjectsRoot()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text(mgr.projectsRoot.lastPathComponent)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                }
                .help(Text("Choose folder…"))
            }
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.vertical, 6)

            DeckHairline()

            if mgr.projects.isEmpty {
                DeckEmptyState(
                    symbol: "folder.badge.questionmark",
                    tint: .green,
                    title: "No folders in \(mgr.projectsRoot.lastPathComponent)",
                    minHeight: 170
                ) {
                    DeckActionButton(
                        variant: .tinted(.green),
                        cornerRadius: 16,
                        horizontalPadding: 12,
                        verticalPadding: 5
                    ) {
                        mgr.chooseProjectsRoot()
                    } label: {
                        Text("Choose folder…")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                }
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(mgr.projects) { project in
                            ProjectRow(project: project) {
                                if let opener { mgr.open(project, in: opener) }
                            }
                            .contextMenu {
                                ForEach(mgr.apps) { app in
                                    Button("Open in \(app.name)") { mgr.open(project, in: app) }
                                }
                                Divider()
                                Button("Show in Finder") { mgr.showInFinder(project) }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }
}

// MARK: – Tile

private struct DevAppTile<Icon: View>: View {
    let name: String
    var isDashed: Bool = false
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            VStack(spacing: 5) {
                icon()
                Text(name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 3)
            .background(
                Color.primary.opacity(isHovered ? 0.085 : (isDashed ? 0.02 : 0.04)),
                in: shape
            )
            .overlay {
                if isDashed {
                    shape.strokeBorder(
                        Color.primary.opacity(isHovered ? 0.22 : 0.12),
                        style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                    )
                } else {
                    shape.strokeBorder(
                        Color.primary.opacity(isHovered ? 0.12 : 0.065),
                        lineWidth: 0.5
                    )
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(DeckPressStyle(scale: 0.96))
        .help(name)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}

// MARK: – Project row

private struct ProjectRow: View {
    let project: DevAppsManager.Project
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DeckHoverRow(horizontalPadding: 8, verticalPadding: 6, horizontalInset: 6) { isHovered in
                HStack(spacing: 9) {
                    DeckIconBadge(
                        symbol: "folder.fill",
                        tint: .green,
                        size: 22,
                        iconSize: 10.5,
                        cornerRadius: 6
                    )

                    Text(project.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 6)

                    if isHovered {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text(project.modified.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(DeckPressStyle(scale: 0.985))
    }
}
