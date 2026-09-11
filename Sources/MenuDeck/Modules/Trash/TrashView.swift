import SwiftUI

struct TrashView: View {
    @StateObject private var mgr = TrashManager()
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 0) {
            switch mgr.access {
            case .unknown:
                ProgressView().controlSize(.small).padding(.vertical, 30)
            case .denied:
                permissionState
            case .granted:
                contents
            }
        }
        .onAppear { mgr.refresh() }
    }

    // MARK: – Granted

    private var contents: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(TrashManager.format(mgr.contents.byteSize))
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.gray.gradient)
                    .contentTransition(.numericText())

                Text("\(mgr.contents.itemCount) items in the Trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 14)

            if mgr.contents.itemCount > 0 {
                if isConfirming {
                    confirmation
                } else {
                    actions
                }
            } else {
                Text("Nothing to empty")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
        .padding(.horizontal, 14)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button { mgr.openInFinder() } label: {
                Text("Open")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { isConfirming = true } label: {
                Label("Empty", systemImage: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(mgr.isEmptying)
        }
    }

    private var confirmation: some View {
        VStack(spacing: 7) {
            Text("Permanently delete \(mgr.contents.itemCount) items?")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Button("Cancel") { isConfirming = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    isConfirming = false
                    mgr.empty()
                } label: {
                    Text("Delete")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: – Denied

    private var permissionState: some View {
        VStack(spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)

            Text("Full Disk Access needed")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            // ~/.Trash sits inside the user's own home directory but is still
            // TCC-protected, so there is no lighter permission that covers it.
            Text("macOS protects the Trash folder even inside your home directory.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)

            Button { mgr.openFullDiskAccessSettings() } label: {
                Text("Open Privacy settings")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
