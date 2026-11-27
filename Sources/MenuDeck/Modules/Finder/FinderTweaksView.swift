import SwiftUI

struct FinderTweaksView: View {
    @StateObject private var mgr = FinderTweaksManager()

    var body: some View {
        VStack(spacing: 10) {
            DeckGroupedList(dividerInset: 40) {
                ForEach(FinderTweaksManager.Tweak.allCases) { tweak in
                    row(tweak)
                }
            }

            footer
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown { mgr.refresh() }
    }

    private func row(_ tweak: FinderTweaksManager.Tweak) -> some View {
        let isOn = mgr.value(for: tweak)
        return HStack(spacing: 9) {
            DeckIconBadge(
                symbol: tweak.sfSymbol,
                tint: .cyan,
                size: 24,
                iconSize: 11,
                isActive: isOn
            )

            Text(tweak.label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isOn ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { mgr.set($0, for: tweak) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .tint(.cyan)
            .disabled(mgr.isApplying)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var footer: some View {
        Group {
            if mgr.isApplying {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                    Text("Relaunching Finder…")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                DeckStatusBanner(
                    icon: "info.circle.fill",
                    tint: .secondary,
                    title: Text("Each change relaunches Finder")
                )
            }
        }
    }
}
