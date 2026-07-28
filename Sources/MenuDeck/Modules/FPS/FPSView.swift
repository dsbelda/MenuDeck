import SwiftUI

struct FPSView: View {
    @StateObject private var mgr = GPUManager()

    var body: some View {
        VStack(spacing: 0) {
            stat
            Divider().opacity(0.08)
            toggleRow
            note
        }
        .onAppear   { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    // MARK: – GPU stat

    private var stat: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("GPU usage")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(mgr.utilizationPercent.map { "\($0)" } ?? "—")
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.mint.gradient)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: mgr.utilizationPercent)
                    if mgr.utilizationPercent != nil {
                        Text("%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 32, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.mint.gradient)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    // MARK: – Metal HUD toggle

    private var toggleRow: some View {
        Toggle(isOn: $mgr.hudEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show FPS over games")
                    .font(.system(size: 12, weight: .medium))
                Text("Enables Metal's built-in HUD")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(.mint)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var note: some View {
        Text("Reopen the game for it to appear. Only works with apps that use Metal.")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }
}
