import SwiftUI

struct ScreenshotView: View {
    @ObservedObject private var manager = ScreenshotManager.shared
    @State private var target: ScreenshotManager.SaveTarget = .desktop
    @State private var delay: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            captureButtons
            Divider().padding(.horizontal, 14).opacity(0.10)
            optionsRow
            feedbackRow
        }
        .opacity(manager.isCapturing ? 0.5 : 1)
        .allowsHitTesting(!manager.isCapturing)
        .animation(.easeInOut(duration: 0.15), value: manager.isCapturing)
    }

    // MARK: – Capture buttons

    private var captureButtons: some View {
        HStack(spacing: 8) {
            CaptureButton(title: "Pantalla", icon: "display", tint: .teal) {
                manager.capture(mode: .fullScreen, target: target, delay: delay)
            }
            CaptureButton(title: "Área", icon: "selection.pin.in.out", tint: .teal) {
                manager.capture(mode: .area, target: target, delay: delay)
            }
            CaptureButton(title: "Ventana", icon: "macwindow", tint: .teal) {
                manager.capture(mode: .window, target: target, delay: delay)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: – Options row

    private var optionsRow: some View {
        HStack(spacing: 0) {
            // Destination
            HStack(spacing: 5) {
                Image(systemName: target == .desktop ? "folder" : "doc.on.clipboard")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Picker("", selection: $target) {
                    Text("Escritorio").tag(ScreenshotManager.SaveTarget.desktop)
                    Text("Portapapeles").tag(ScreenshotManager.SaveTarget.clipboard)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.mini)
            }

            Spacer()

            // Timer delay
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Picker("", selection: $delay) {
                    Text("Sin retardo").tag(0)
                    Text("3 s").tag(3)
                    Text("5 s").tag(5)
                    Text("10 s").tag(10)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: – Feedback

    @ViewBuilder
    private var feedbackRow: some View {
        switch manager.lastResult {
        case .none:
            EmptyView()

        case .cancelled:
            feedback(icon: "exclamationmark.triangle.fill", tint: .orange) {
                Text("Captura cancelada")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

        case .failed(let message):
            feedback(icon: "exclamationmark.triangle.fill", tint: .orange) {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

        case .clipboard:
            feedback(icon: "checkmark.circle.fill", tint: .green) {
                Text("Copiado al portapapeles")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

        case .file(let url):
            feedback(icon: "checkmark.circle.fill", tint: .green) {
                Text(url.lastPathComponent)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Mostrar en Finder")
            }
        }
    }

    private func feedback<C: View>(
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> C
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .transition(.opacity)
    }
}

// MARK: – Capture Button

private struct CaptureButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(height: 26)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.20), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
