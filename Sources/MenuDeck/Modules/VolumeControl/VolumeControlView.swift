import SwiftUI
import AppKit

struct VolumeControlView: View {
    @ObservedObject private var manager = CoreAudioManager.shared

    var body: some View {
        VStack(spacing: 8) {
            if let err = manager.lastPermissionError {
                permissionBanner(message: err)
            }
            if manager.apps.isEmpty {
                DeckEmptyState(
                    symbol: "speaker.wave.3",
                    tint: .blue,
                    title: "No audio apps",
                    subtitle: "Open an app and play something",
                    minHeight: manager.lastPermissionError == nil
                        ? DeckMetrics.moduleHeight - 24
                        : 170
                )
            } else {
                ForEach($manager.apps) { $app in
                    AppVolumeRow(app: $app, manager: manager)
                }
            }
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown { manager.refresh() }
    }

    private func permissionBanner(message: String) -> some View {
        DeckStatusBanner(
            icon: "lock.shield.fill",
            tint: .orange,
            title: Text("Audio Capture needed"),
            subtitle: Text("Settings → Privacy & Security → Audio Capture")
        ) {
            DeckActionButton(
                variant: .tinted(.orange),
                cornerRadius: 6,
                horizontalPadding: 8,
                verticalPadding: 4
            ) {
                manager.openPrivacySettings()
            } label: {
                Text("Open")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
    }
}

// MARK: – Row

struct AppVolumeRow: View {
    @Binding var app: AudioApp
    let manager: CoreAudioManager

    var body: some View {
        DeckCard(padding: 10) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    appIcon

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            volumePill
                            muteButton
                        }

                        volumeSlider
                    }
                }

                if let err = app.controlError {
                    DeckStatusBanner(
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange,
                        title: Text(err)
                    )
                }
            }
        }
    }

    private var appIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "app.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        app.isControlled ? Color.blue.opacity(0.55) : Color.primary.opacity(0.09),
                        lineWidth: app.isControlled ? 1.25 : 0.5
                    )
            )

            if app.isControlled {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                    .offset(x: 2.5, y: 2.5)
            }
        }
    }

    private var volumePill: some View {
        Text(app.isMuted ? String(localized: "muted") : "\(Int(app.volume * 100))%")
            .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(app.isMuted ? .red : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                (app.isMuted ? Color.red : Color.primary).opacity(app.isMuted ? 0.13 : 0.065),
                in: Capsule()
            )
            .animation(.none, value: app.isMuted)
    }

    private var muteButton: some View {
        DeckIconButton(
            symbol: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            size: 22,
            iconSize: 11,
            tint: app.isMuted ? .red : .secondary,
            hoverTint: app.isMuted ? .red : .primary,
            restingFill: app.isMuted ? 0.10 : 0.05
        ) {
            manager.toggleMute(for: app)
        }
    }

    private var volumeSlider: some View {
        Slider(
            value: Binding(
                get: { app.isMuted ? 0 : app.volume },
                set: { manager.setVolume($0, for: app) }
            ),
            in: 0...1
        )
        .tint(app.isMuted ? .red.opacity(0.45) : .blue)
        .controlSize(.small)
    }
}
