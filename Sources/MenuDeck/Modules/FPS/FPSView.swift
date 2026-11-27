import SwiftUI

struct FPSView: View {
    @StateObject private var mgr = GPUManager()

    var body: some View {
        VStack(spacing: 10) {
            statCard
            toggleCard
            noteBanner
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(mgr.start, stop: mgr.stop)
    }

    // MARK: – GPU stat

    private var statCard: some View {
        DeckCard(padding: 12) {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GPU usage")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(mgr.utilizationPercent.map { "\($0)" } ?? "—")
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.mint.gradient)
                                .contentTransition(.numericText())
                            if mgr.utilizationPercent != nil {
                                Text("%")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    DeckIconBadge(
                        symbol: "gauge.with.dots.needle.67percent",
                        tint: .mint,
                        size: 42,
                        iconSize: 20,
                        cornerRadius: 12
                    )
                }

                if let pct = mgr.utilizationPercent {
                    DeckProgressBar(fraction: Double(pct) / 100.0, tint: .mint, height: 6)
                }
            }
        }
    }

    // MARK: – Metal HUD toggle

    private var toggleCard: some View {
        DeckCard(padding: 11) {
            HStack(spacing: 10) {
                DeckIconBadge(
                    symbol: "gamecontroller.fill",
                    tint: .mint,
                    size: 26,
                    iconSize: 12,
                    isActive: mgr.hudEnabled
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Show FPS over games")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("Enables Metal's built-in HUD")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Toggle("", isOn: $mgr.hudEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .tint(.mint)
            }
        }
    }

    private var noteBanner: some View {
        DeckStatusBanner(
            icon: "info.circle.fill",
            tint: .secondary,
            title: Text("Reopen the game for it to appear. Only works with apps that use Metal.")
        )
    }
}
