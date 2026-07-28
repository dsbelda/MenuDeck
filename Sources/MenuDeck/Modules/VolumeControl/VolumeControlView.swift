import SwiftUI
import AppKit

struct VolumeControlView: View {
    @ObservedObject private var manager = CoreAudioManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if let err = manager.lastPermissionError {
                permissionBanner(message: err)
            }
            if manager.apps.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach($manager.apps) { $app in
                        AppVolumeRow(app: $app, manager: manager)
                        if app.id != manager.apps.last?.id {
                            Divider()
                                .padding(.leading, 66)
                                .opacity(0.08)
                        }
                    }
                }
            }
        }
        .onAppear { manager.refresh() }
    }

    private func permissionBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Audio Capture needed")
                    .font(.system(size: 11, weight: .semibold))
                Text("Settings → Privacy → Audio Capture")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open") { manager.openPrivacySettings() }
                .buttonStyle(.glassProminent)
                .controlSize(.mini)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("No audio apps")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Open an app and play something")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: – Row

struct AppVolumeRow: View {
    @Binding var app: AudioApp
    let manager: CoreAudioManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                appIcon

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Spacer()

                        volumePill
                        muteButton
                    }
                    volumeSlider
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if let err = app.controlError {
                errorRow(err)
            }
        }
    }

    private var appIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let icon = resolvedIcon(for: app) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 40, height: 40)
                    Image(systemName: "app.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        app.isControlled ? Color.blue.opacity(0.55) : Color.white.opacity(0.08),
                        lineWidth: app.isControlled ? 1.5 : 0.5
                    )
            )

            if app.isControlled {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1))
                    .offset(x: 3, y: 3)
            }
        }
    }

    private var volumePill: some View {
        Text(app.isMuted ? "muted" : "\(Int(app.volume * 100))%")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(app.isMuted ? .red : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                (app.isMuted ? Color.red : Color.secondary).opacity(0.12),
                in: Capsule()
            )
            .animation(.none, value: app.isMuted)
    }

    private var muteButton: some View {
        Button {
            manager.toggleMute(for: app)
        } label: {
            Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(app.isMuted ? .red : .secondary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var volumeSlider: some View {
        Slider(
            value: Binding(
                get: { app.isMuted ? 0 : app.volume },
                set: { manager.setVolume($0, for: app) }
            ),
            in: 0...1
        )
        .tint(app.isMuted ? .red.opacity(0.4) : .blue)
        .controlSize(.small)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.multicolor)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func resolvedIcon(for app: AudioApp) -> NSImage? {
        let ownApp = NSRunningApplication(processIdentifier: app.pid)
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        // 1. It IS a regular app — use its icon directly.
        if ownApp?.activationPolicy == .regular { return ownApp?.icon }

        // 2. Exact name match among regular apps.
        if let m = regular.first(where: { $0.localizedName == app.name }) { return m.icon }

        // 3. Bundle ID prefix: strip components from the right until we hit a regular app.
        //    e.g. "com.apple.WebKit.GPU" → try "com.apple.WebKit" → "com.apple" (skip, too generic)
        if let bid = ownApp?.bundleIdentifier {
            var parts = bid.components(separatedBy: ".")
            while parts.count > 2 {
                parts.removeLast()
                let prefix = parts.joined(separator: ".")
                if let m = regular.first(where: { $0.bundleIdentifier == prefix }) { return m.icon }
            }
        }

        // 4. Name-word prefix: "Safari Graphics and Audio Process" → try "Safari Graphics and",
        //    "Safari Graphics", "Safari" — stops at the first match with a regular app.
        //    Handles Chrome helpers ("Google Chrome Helper" → "Google Chrome"), etc.
        let words = app.name.components(separatedBy: " ").filter { !$0.isEmpty }
        for n in stride(from: words.count, through: 1, by: -1) {
            let candidate = words.prefix(n).joined(separator: " ")
            guard candidate.count >= 3 else { break }
            if let m = regular.first(where: {
                $0.localizedName == candidate ||
                $0.localizedName?.hasPrefix(candidate + " ") == true
            }) { return m.icon }
        }

        return ownApp?.icon
    }
}
