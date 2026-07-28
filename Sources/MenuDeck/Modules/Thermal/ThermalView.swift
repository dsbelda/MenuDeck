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

            // Probing every selector and enumerating the whole key space is
            // ~100 blocking IOKit calls. It is debug instrumentation, and it
            // used to run on the main thread on every tile tap.
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
        thermalState = ProcessInfo.processInfo.thermalState
        Task { readings = await SMCManager.shared.readTemperatures() }
    }
}

struct ThermalView: View {
    @StateObject private var vm = ThermalViewModel()
    @State private var showLogs = false

    var body: some View {
        VStack(spacing: 0) {
            thermalHero

            if vm.readings.isEmpty {
                noDataRow
            } else {
                let groups = groupedReadings(vm.readings)
                ForEach(groups, id: \.0) { groupName, items in
                    sectionGroup(name: groupName, items: items)
                }
            }

            // Persistent logs panel — always accessible, unaffected by refresh
            if let diag = vm.diagnostics {
                logsPanel(diag)
            }
        }
        .onAppear  { vm.start() }
        .onDisappear { vm.stop() }
    }

    private func logsPanel(_ text: String) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 14).opacity(0.08)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showLogs.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .medium))
                    Text("SMC Logs")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: showLogs ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showLogs {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(text)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 240)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: – Hero

    private var thermalHero: some View {
        HStack(alignment: .center, spacing: 0) {
            if let maxTemp = vm.maxCPUTemp {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.0f", maxTemp))
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(tempColor(maxTemp).gradient)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.5), value: maxTemp)
                        Text("°C")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .offset(y: -2)
                    }
                    Text("CPU peak")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("No sensor data")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            thermalBadge
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var thermalBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: pressureIcon(vm.thermalState))
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            Text(pressureLabel(vm.thermalState))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(pressureColor(vm.thermalState))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(pressureColor(vm.thermalState).opacity(0.14), in: Capsule())
    }

    // MARK: – Sensor groups

    private func sectionGroup(name: String, items: [TempReading]) -> some View {
        VStack(spacing: 0) {
            HStack {
                // The group name doubles as the ForEach id, so it stays a
                // String and gets looked up here.
                Text(LocalizedStringKey(name))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.10), in: Capsule())
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ForEach(items) { reading in
                TempRow(reading: reading)
                if reading.id != items.last?.id {
                    Divider()
                        .padding(.horizontal, 14)
                        .opacity(0.08)
                }
            }
        }
    }

    private var noDataRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 2) {
                Text("SMC unavailable")
                    .font(.system(size: 12, weight: .semibold))
                Text(vm.smcError ?? String(localized: "No temperature keys found"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        case ..<75: return .yellow
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
        case .fair:       return .yellow
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
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 72, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.06))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [barColor(reading.value).opacity(0.6), barColor(reading.value)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(7, geo.size.width * fillFraction(reading.value)), height: 7)
                        .animation(.easeOut(duration: 0.5), value: reading.value)
                }
            }
            .frame(height: 7)

            Text(String(format: "%.0f°C", reading.value))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(barColor(reading.value))
                .frame(width: 38, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5), value: reading.value)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func fillFraction(_ temp: Double) -> Double {
        min(max((temp - 20) / (110 - 20), 0), 1)
    }

    private func barColor(_ temp: Double) -> Color {
        switch temp {
        case ..<60:  return .green
        case ..<80:  return .yellow
        case ..<95:  return .orange
        default:     return .red
        }
    }
}
