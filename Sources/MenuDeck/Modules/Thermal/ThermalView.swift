import SwiftUI

@MainActor
final class ThermalViewModel: ObservableObject {
    @Published var readings: [TempReading] = []
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var smcError: String? = nil
    @Published var diagnostics: String? = nil

    /// Opt in with: defaults write com.menudeck.app menudeck.debug.smc -bool YES
    private static let diagnosticsKey = "menudeck.debug.smc"

    private var timer: Timer?

    var maxCPUTemp: Double? {
        readings.filter { $0.group == .cpu }.map(\.value).max()
    }

    func start() {
        Task {
            smcError = await SMCManager.shared.openFailure()

            if UserDefaults.standard.bool(forKey: Self.diagnosticsKey) {
                diagnostics = await SMCManager.shared.runDiagnostics()
            }
        }

        refresh()
        timer = .repeating(every: 3, tolerance: 0.7) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let state = ProcessInfo.processInfo.thermalState
        if state != thermalState { thermalState = state }
        Task {
            let fresh = await SMCManager.shared.readTemperatures()
            if fresh != readings { readings = fresh }
        }
    }
}

struct ThermalView: View {
    @StateObject private var vm = ThermalViewModel()
    @State private var showLogs = false

    var body: some View {
        VStack(spacing: 10) {
            thermalHero

            if vm.readings.isEmpty {
                noDataRow
            } else {
                let groups = groupedReadings(vm.readings)
                ForEach(groups, id: \.0) { groupName, items in
                    sectionGroup(name: groupName, items: items)
                }
            }

            if let diag = vm.diagnostics {
                logsPanel(diag)
            }
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(vm.start, stop: vm.stop)
    }

    // MARK: – Hero

    private var thermalHero: some View {
        DeckCard(padding: 12) {
            HStack(alignment: .center, spacing: 8) {
                if let maxTemp = vm.maxCPUTemp {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.0f", maxTemp))
                                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(tempColor(maxTemp).gradient)
                                .contentTransition(.numericText())
                            Text("°C")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Text("CPU peak")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No sensor data")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                thermalBadge
            }
        }
    }

    private var thermalBadge: some View {
        let color = pressureColor(vm.thermalState)
        return HStack(spacing: 5) {
            Image(systemName: pressureIcon(vm.thermalState))
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
            Text(pressureLabel(vm.thermalState))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: – Sensor groups

    private func sectionGroup(name: String, items: [TempReading]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DeckSectionHeader(
                LocalizedStringKey(name),
                icon: groupIcon(name),
                tint: .orange
            )
            .padding(.horizontal, 4)

            DeckGroupedList(dividerInset: 10) {
                ForEach(items) { reading in
                    TempRow(reading: reading)
                }
            }
        }
    }

    private func groupIcon(_ name: String) -> String {
        switch name {
        case "CPU": return "cpu"
        case "GPU": return "rectangle.3.group"
        default:    return "thermometer.medium"
        }
    }

    private var noDataRow: some View {
        DeckStatusBanner(
            icon: "exclamationmark.triangle.fill",
            tint: .orange,
            title: Text("SMC unavailable"),
            subtitle: Text(vm.smcError ?? String(localized: "No temperature keys found"))
        )
    }

    private func logsPanel(_ text: String) -> some View {
        DeckCard {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        showLogs.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.system(size: 10, weight: .semibold))
                        Text("SMC Logs")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: showLogs ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showLogs {
                    DeckHairline()
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(text)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }

    // MARK: – Helpers

    private func groupedReadings(_ readings: [TempReading]) -> [(String, [TempReading])] {
        var result: [(String, [TempReading])] = []
        let cpu = readings.filter { $0.group == .cpu }
        let gpu = readings.filter { $0.group == .gpu }
        let sys = readings.filter { $0.group == .system }
        if !cpu.isEmpty { result.append(("CPU", cpu)) }
        if !gpu.isEmpty { result.append(("GPU", gpu)) }
        if !sys.isEmpty { result.append(("System", sys)) }
        return result
    }

    private func tempColor(_ temp: Double) -> Color {
        switch temp {
        case ..<55: return .green
        case ..<75: return Color(red: 0.90, green: 0.65, blue: 0.06)
        case ..<90: return .orange
        default:    return .red
        }
    }

    private func pressureLabel(_ state: ProcessInfo.ThermalState) -> LocalizedStringResource {
        switch state {
        case .nominal:    return "Normal"
        case .fair:       return "Fair"
        case .serious:    return "High"
        case .critical:   return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private func pressureColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal:    return .green
        case .fair:       return Color(red: 0.90, green: 0.65, blue: 0.06)
        case .serious:    return .orange
        case .critical:   return .red
        @unknown default: return .secondary
        }
    }

    private func pressureIcon(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:    return "checkmark.circle.fill"
        case .fair:       return "exclamationmark.circle.fill"
        case .serious:    return "exclamationmark.triangle.fill"
        case .critical:   return "flame.fill"
        @unknown default: return "questionmark.circle"
        }
    }
}

// MARK: – Temperature Row

struct TempRow: View {
    let reading: TempReading

    var body: some View {
        HStack(spacing: 10) {
            Text(reading.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 74, alignment: .leading)
                .lineLimit(1)

            DeckProgressBar(
                fraction: fillFraction(reading.value),
                tint: barColor(reading.value),
                height: 6
            )

            Text(String(format: "%.0f°C", reading.value))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(barColor(reading.value))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func fillFraction(_ temp: Double) -> Double {
        min(max((temp - 20) / (110 - 20), 0), 1)
    }

    private func barColor(_ temp: Double) -> Color {
        switch temp {
        case ..<60:  return .green
        case ..<80:  return Color(red: 0.90, green: 0.65, blue: 0.06)
        case ..<95:  return .orange
        default:     return .red
        }
    }
}
