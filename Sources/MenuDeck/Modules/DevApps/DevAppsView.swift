import SwiftUI

struct DevAppsView: View {
    @StateObject private var mgr = DevAppsManager()
    @AppStorage("menudeck.devTab") private var tab: Tab = .apps
    @AppStorage("menudeck.devProjectApp") private var openerID = ""

    private enum Tab: String { case apps, projects }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Apps").tag(Tab.apps)
                Text("Projects").tag(Tab.projects)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 7)

            Divider().opacity(0.08)

            switch tab {
            case .apps:     appGrid
            case .projects: projectList
            }
        }
        // Every open, not once: an app installed or a project touched since the
        // last look should not need the module switched off and on to notice.
        .whileShown { mgr.refresh() }
    }

    // MARK: – Apps

    private var appGrid: some View {
        ScrollView(.vertical) {
            VStack(spacing: 6) {
                LazyVGrid(columns: columns, spacing: 6) {
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

                    DevAppTile(name: String(localized: "Add")) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } action: {
                        mgr.pickApps()
                    }
                }

                if !mgr.apps.isEmpty {
                    Text("Right-click an app to remove it")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: – Projects

    /// The app a click opens a project in: the one chosen, or the first pinned
    /// app while nothing has been — or once the chosen one is unpinned.
    private var opener: DevAppsManager.App? {
        mgr.apps.first { $0.bundleID == openerID } ?? mgr.apps.first
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if let opener {
                    Text("Open with")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
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

                Spacer()

                Button { mgr.chooseProjectsRoot() } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(Text("Choose folder…"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            Divider().opacity(0.08)

            if mgr.projects.isEmpty {
                noProjects
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
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
                    .padding(.vertical, 2)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var noProjects: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("No folders in \(mgr.projectsRoot.lastPathComponent)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Button { mgr.chooseProjectsRoot() } label: {
                Text("Choose folder…")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Tile

private struct DevAppTile<Icon: View>: View {
    let name: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon()
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    // Two lines, always reserved: "Visual Studio Code" fits
                    // and the rows stay level.
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 2)
            .background(
                Color.primary.opacity(isHovered ? 0.06 : 0),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(name)
        .onHover { isHovered = $0 }
    }
}

// MARK: – Project row

private struct ProjectRow: View {
    let project: DevAppsManager.Project
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                    .frame(width: 16)

                Text(project.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                Text(project.modified.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
