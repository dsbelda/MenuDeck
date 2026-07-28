import SwiftUI

struct NetworkView: View {
    @StateObject private var mgr = NetworkManager()

    var body: some View {
        VStack(spacing: 0) {
            speeds
            Divider().opacity(0.08)
            info
        }
        .onAppear   { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    // MARK: – Speeds

    private var speeds: some View {
        HStack(spacing: 0) {
            speedCell(icon: "arrow.down", label: "Down", value: mgr.downKBps)
            Divider().frame(height: 40).opacity(0.12)
            speedCell(icon: "arrow.up", label: "Up", value: mgr.upKBps)
        }
        .padding(.vertical, 14)
    }

    private func speedCell(icon: String, label: LocalizedStringKey, value: Double) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.cyan)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            Text(Self.formatSpeed(value))
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: value)
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatSpeed(_ kbps: Double) -> String {
        kbps >= 1024 ? String(format: "%.1f MB/s", kbps / 1024) : String(format: "%.0f KB/s", kbps)
    }

    // MARK: – Info

    private var info: some View {
        VStack(spacing: 10) {
            infoRow(icon: "wifi", value: mgr.isWiFi ? (mgr.ssid ?? "Wi-Fi") : String(localized: "No Wi-Fi"), showSignal: mgr.isWiFi)
            infoRow(icon: "network", value: mgr.localIP ?? String(localized: "Offline"), showSignal: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoRow(icon: String, value: String, showSignal: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            if showSignal {
                signalGlyph
            }
        }
    }

    private var signalGlyph: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i < mgr.signalBars ? Color.cyan : Color.secondary.opacity(0.25))
                    .frame(width: 3, height: 5 + CGFloat(i) * 3)
            }
        }
    }
}
