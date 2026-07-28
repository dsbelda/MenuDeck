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
                    Text("Mantener el Mac despierto")
                        .font(.system(size: 12, weight: .medium))
                    Text(mgr.isActive ? statusText : "Evita que se suspenda o bloquee la pantalla")
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
        guard let remaining = mgr.remainingSeconds else { return "Activo indefinidamente" }
        let h = remaining / 3600, m = (remaining % 3600) / 60, s = remaining % 60
        return h > 0
            ? String(format: "Activo · %d:%02d:%02d restantes", h, m, s)
            : String(format: "Activo · %d:%02d restantes", m, s)
    }

    private var durationPicker: some View {
        HStack {
            Text("Duración")
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
