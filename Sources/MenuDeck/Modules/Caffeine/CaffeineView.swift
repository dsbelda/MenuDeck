import SwiftUI

struct CaffeineView: View {
    @ObservedObject private var mgr = CaffeineManager.shared
    @ObservedObject private var popover = PopoverState.shared

    var body: some View {
        VStack(spacing: 10) {
            statusCard
            durationCard
        }
        .padding(DeckMetrics.horizontalPadding)
    }

    private var statusCard: some View {
        DeckCard(padding: 12) {
            HStack(spacing: 10) {
                DeckIconBadge(
                    symbol: mgr.isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
                    tint: .brown,
                    size: 36,
                    iconSize: 17,
                    isActive: mgr.isActive,
                    cornerRadius: 10
                )

                VStack(alignment: .leading, spacing: 2.5) {
                    Text("Keep the Mac awake")
                        .font(.system(size: 12, weight: .semibold))
                    status
                        .font(.system(size: 10.5, weight: mgr.isActive ? .medium : .regular))
                        .foregroundStyle(mgr.isActive ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Toggle("", isOn: $mgr.isActive)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .tint(.brown)
            }
        }
    }

    private var status: Text {
        guard mgr.isActive else { return Text("Prevents sleep and screen lock") }
        guard let end = mgr.endDate else { return Text("Active indefinitely") }
        guard popover.isShown else { return Text(verbatim: " ") }
        return Text("Active · \(Text(timerInterval: Date.now...max(end, .now))) left")
    }

    private var durationCard: some View {
        DeckCard(padding: 11) {
            VStack(alignment: .leading, spacing: 9) {
                DeckSectionHeader("Duration", icon: "timer", tint: .brown)

                let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(CaffeineManager.durations.indices, id: \.self) { i in
                        DurationChip(
                            label: CaffeineManager.durations[i].label,
                            isSelected: mgr.selectedDurationIndex == i,
                            isDisabled: mgr.isActive
                        ) {
                            mgr.selectedDurationIndex = i
                        }
                    }
                }
            }
        }
        .opacity(mgr.isActive ? 0.55 : 1)
    }
}

private struct DurationChip: View {
    let label: LocalizedStringResource
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : (isHovered ? .primary : .secondary))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .padding(.horizontal, 4)
                .background(
                    isSelected
                        ? Color.brown.opacity(0.24)
                        : Color.primary.opacity(isHovered && !isDisabled ? 0.08 : 0.045),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.brown.opacity(0.55) : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 0.8 : 0.5
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(DeckPressStyle(scale: 0.96))
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}
