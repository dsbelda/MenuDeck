import AppKit
import SwiftUI

struct NetworkView: View {
    @StateObject private var mgr = NetworkManager()
    @State private var copiedIP = false

    var body: some View {
        VStack(spacing: 10) {
            speedsCard
            infoCard
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(mgr.start, stop: mgr.stop)
    }

    // MARK: – Speeds

    private var speedsCard: some View {
        DeckCard {
            HStack(spacing: 0) {
                speedCell(icon: "arrow.down", tint: .cyan, label: "Down", value: mgr.downKBps)
                Divider().frame(height: 40).opacity(0.12)
                speedCell(icon: "arrow.up", tint: .blue, label: "Up", value: mgr.upKBps)
            }
            .padding(.vertical, 14)
        }
    }

    private func speedCell(icon: String, tint: Color, label: LocalizedStringKey, value: Double) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(Self.formatSpeed(value))
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatSpeed(_ kbps: Double) -> String {
        kbps >= 1024 ? String(format: "%.1f MB/s", kbps / 1024) : String(format: "%.0f KB/s", kbps)
    }

    // MARK: – Connection Info

    private var infoCard: some View {
        DeckGroupedList(dividerInset: 40) {
            HStack(spacing: 9) {
                DeckIconBadge(
                    symbol: mgr.isWiFi ? "wifi" : "wifi.slash",
                    tint: .cyan,
                    size: 24,
                    iconSize: 11,
                    isActive: mgr.isWiFi
                )
                Text(mgr.isWiFi ? (mgr.ssid ?? "Wi-Fi") : String(localized: "No Wi-Fi"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(mgr.isWiFi ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
                if mgr.isWiFi {
                    signalGlyph
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            ipRow
        }
    }

    private var ipRow: some View {
        Button {
            guard let ip = mgr.localIP else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ip, forType: .string)
            withAnimation(.easeOut(duration: 0.15)) { copiedIP = true }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeOut(duration: 0.15)) { copiedIP = false }
            }
        } label: {
            DeckHoverRow(
                horizontalPadding: 10,
                verticalPadding: 7,
                horizontalInset: 0,
                isInteractive: mgr.localIP != nil
            ) { isHovered in
                HStack(spacing: 9) {
                    DeckIconBadge(
                        symbol: "network",
                        tint: .blue,
                        size: 24,
                        iconSize: 11,
                        isActive: mgr.localIP != nil
                    )

                    Text(mgr.localIP ?? String(localized: "Offline"))
                        .font(.system(size: 11.5, weight: .medium, design: mgr.localIP != nil ? .monospaced : .default))
                        .foregroundStyle(mgr.localIP != nil ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    if copiedIP {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Copied")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundStyle(.green)
                    } else if isHovered && mgr.localIP != nil {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(mgr.localIP == nil)
        .help(mgr.localIP != nil ? Text("Copy IP") : Text(""))
    }

    private var signalGlyph: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i < mgr.signalBars ? Color.cyan : Color.primary.opacity(0.14))
                    .frame(width: 3, height: 5 + CGFloat(i) * 3.5)
            }
        }
    }
}
