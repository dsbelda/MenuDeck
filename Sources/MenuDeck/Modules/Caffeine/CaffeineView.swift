import SwiftUI

struct CaffeineView: View {
    @ObservedObject private var mgr = CaffeineManager.shared

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
                    Text(mgr.isActive ? statusText : String(localized: "Prevents sleep and screen lock"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.brown)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusText: String {
        guard let remaining = mgr.remainingSeconds else {
            return String(localized: "Active indefinitely")
        }
        let h = remaining / 3600, m = (remaining % 3600) / 60, s = remaining % 60
        // Formatted separately so the localized string carries one clock
        // placeholder rather than three positional integers.
        let clock = h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                          : String(format: "%d:%02d", m, s)
        return String(localized: "Active · \(clock) left")
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
