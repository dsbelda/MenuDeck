import SwiftUI

struct ScreenshotView: View {
    @ObservedObject private var manager = ScreenshotManager.shared
    @State private var target: ScreenshotManager.SaveTarget = .desktop
    @State private var delay: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            captureButtons
            optionsCard
            feedbackRow
        }
        .padding(DeckMetrics.horizontalPadding)
        .opacity(manager.isCapturing ? 0.5 : 1)
        .allowsHitTesting(!manager.isCapturing)
        .animation(.easeInOut(duration: 0.15), value: manager.isCapturing)
    }

    // MARK: – Capture buttons

    private var captureButtons: some View {
        HStack(spacing: 8) {
            CaptureButton(title: "Screen", icon: "display", tint: .teal) {
                manager.capture(mode: .fullScreen, target: target, delay: delay)
            }
            CaptureButton(title: "Selection", icon: "selection.pin.in.out", tint: .teal) {
                manager.capture(mode: .area, target: target, delay: delay)
            }
            CaptureButton(title: "Window", icon: "macwindow", tint: .teal) {
                manager.capture(mode: .window, target: target, delay: delay)
            }
        }
    }

    // MARK: – Options card

    private var optionsCard: some View {
        DeckGroupedList(dividerInset: 38) {
            HStack(spacing: 8) {
                DeckIconBadge(
                    symbol: target == .desktop ? "folder.fill" : "doc.on.clipboard.fill",
                    tint: .teal,
                    size: 22,
                    iconSize: 10,
                    cornerRadius: 6
                )
                Text("Save to")
                    .font(.system(size: 11.5, weight: .medium))
                Spacer()
                Picker("", selection: $target) {
                    Text("Desktop").tag(ScreenshotManager.SaveTarget.desktop)
                    Text("Clipboard").tag(ScreenshotManager.SaveTarget.clipboard)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            HStack(spacing: 8) {
                DeckIconBadge(
                    symbol: "timer",
                    tint: .teal,
                    size: 22,
                    iconSize: 10,
                    isActive: delay > 0,
                    cornerRadius: 6
                )
                Text("Delay")
                    .font(.system(size: 11.5, weight: .medium))
                Spacer()
                Picker("", selection: $delay) {
                    Text("No delay").tag(0)
                    Text("3 s").tag(3)
                    Text("5 s").tag(5)
                    Text("10 s").tag(10)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    // MARK: – Feedback

    @ViewBuilder
    private var feedbackRow: some View {
        switch manager.lastResult {
        case .none:
            EmptyView()

        case .cancelled:
            DeckStatusBanner(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: Text("Capture cancelled")
            )

        case .failed(let message):
            DeckStatusBanner(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: Text(message)
            )

        case .clipboard:
            DeckStatusBanner(
                icon: "checkmark.circle.fill",
                tint: .green,
                title: Text("Copied to clipboard")
            )

        case .file(let url):
            DeckStatusBanner(
                icon: "checkmark.circle.fill",
                tint: .green,
                title: Text(url.lastPathComponent)
            ) {
                DeckIconButton(
                    symbol: "arrow.right.circle.fill",
                    size: 22,
                    iconSize: 12,
                    tint: .green,
                    hoverTint: .green,
                    restingFill: 0.08
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .help("Show in Finder")
            }
        }
    }
}

// MARK: – Capture Button

private struct CaptureButton: View {
    let title: LocalizedStringKey
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(
                        tint.opacity(isHovered ? 0.22 : 0.14),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                tint.opacity(isHovered ? 0.14 : 0.075),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(tint.opacity(isHovered ? 0.34 : 0.18), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(DeckPressStyle(scale: 0.96))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
