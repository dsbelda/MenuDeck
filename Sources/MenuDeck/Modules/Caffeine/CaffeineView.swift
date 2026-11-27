import SwiftUI

struct CaffeineView: View {
    @ObservedObject private var mgr = CaffeineManager.shared
    @ObservedObject private var popover = PopoverState.shared

    var body: some View {
        VStack(spacing: 0) {
            toggleRow
            Divider().opacity(0.08)
            durationPicker
        }
    }

    private var toggleRow: some View {
        HStack(alignment: .top) {
            Toggle(isOn: $mgr.isActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep the Mac awake")
                        .font(.system(size: 12, weight: .medium))
                    status
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                // Without this the toggle hugs its label and the pair floats
                // in the middle of the row.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.brown)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var status: Text {
        guard mgr.isActive else { return Text("Prevents sleep and screen lock") }
        guard let end = mgr.endDate else { return Text("Active indefinitely") }
        // A timer text redraws itself every second whether or not its window is
        // on screen, so it only exists while the popover does.
        guard popover.isShown else { return Text(verbatim: " ") }
        // max(): the range traps if the session ended a moment before the
        // expiry timer got round to saying so.
        return Text("Active · \(Text(timerInterval: Date.now...max(end, .now))) left")
    }

    private var durationPicker: some View {
        HStack {
            Text("Duration")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Picker("", selection: $mgr.selectedDurationIndex) {
                ForEach(CaffeineManager.durations.indices, id: \.self) { i in
                    Text(CaffeineManager.durations[i].label).tag(i)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .disabled(mgr.isActive)
        }
        .opacity(mgr.isActive ? 0.5 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
