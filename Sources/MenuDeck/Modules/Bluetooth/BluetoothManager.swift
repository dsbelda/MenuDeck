import Foundation
import IOBluetooth

@MainActor
final class BluetoothManager: ObservableObject {
    struct Device: Identifiable, Equatable, Sendable {
        let address: String
        let name: String
        let symbol: String
        let isConnected: Bool
        var id: String { address }
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var busyAddress: String?
    @Published private(set) var lastError: String?

    private var timer: Timer?

    func start() {
        refresh()
        guard timer == nil else { return }
        // IOBluetooth has notification registrations, but they deliver on their
        // own run loop sources and only cover connect/disconnect — a poll keeps
        // pairing changes in view too, and the list is tiny.
        timer = .repeating(every: 3, tolerance: 1) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []

        devices = paired.compactMap { device in
            guard let address = device.addressString else { return nil }
            return Device(
                address: address,
                name: device.name ?? address,
                symbol: Self.symbol(
                    major: device.deviceClassMajor,
                    minor: device.deviceClassMinor
                ),
                isConnected: device.isConnected()
            )
        }
        .sorted {
            // Connected first, then alphabetical.
            $0.isConnected == $1.isConnected
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.isConnected
        }
    }

    func toggle(_ device: Device) {
        guard busyAddress == nil else { return }
        busyAddress = device.address
        lastError = nil

        let address = device.address
        let shouldConnect = !device.isConnected

        Task.detached(priority: .userInitiated) {
            // openConnection blocks until the link is up or times out, so it
            // never runs on the main actor. IOBluetoothDevice is not Sendable,
            // hence the re-lookup by address inside the task rather than
            // carrying the object across.
            let ok = Self.setConnection(shouldConnect, address: address)

            await MainActor.run {
                self.busyAddress = nil
                if !ok {
                    self.lastError = shouldConnect
                        ? String(localized: "Could not connect to \(device.name)")
                        : String(localized: "Could not disconnect \(device.name)")
                }
                self.refresh()
            }
        }
    }

    private nonisolated static func setConnection(_ connect: Bool, address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        let status = connect ? device.openConnection() : device.closeConnection()
        return status == kIOReturnSuccess
    }

    /// Bluetooth "class of device" major/minor codes. BLE-only peripherals
    /// report 0 here, so plenty of modern mice and keyboards fall through to the
    /// generic symbol — there is no public API that classifies those.
    private nonisolated static func symbol(major: BluetoothDeviceClassMajor, minor: BluetoothDeviceClassMinor) -> String {
        switch major {
        case UInt32(kBluetoothDeviceClassMajorAudio):
            return "headphones"
        case UInt32(kBluetoothDeviceClassMajorPeripheral):
            switch minor {
            case UInt32(kBluetoothDeviceClassMinorPeripheral1Keyboard):  return "keyboard"
            case UInt32(kBluetoothDeviceClassMinorPeripheral1Pointing):  return "computermouse"
            default:                                                     return "gamecontroller"
            }
        case UInt32(kBluetoothDeviceClassMajorPhone):
            return "iphone"
        case UInt32(kBluetoothDeviceClassMajorComputer):
            return "laptopcomputer"
        default:
            return "dot.radiowaves.left.and.right"
        }
    }
}
