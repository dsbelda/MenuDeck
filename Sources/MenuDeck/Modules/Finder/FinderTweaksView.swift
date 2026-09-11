import SwiftUI

struct FinderTweaksView: View {
    @StateObject private var mgr = FinderTweaksManager()

    var body: some View {
        VStack(spacing: 0) {
            ForEach(FinderTweaksManager.Tweak.allCases) { tweak in
                row(tweak)
                if tweak != FinderTweaksManager.Tweak.allCases.last {
                    Divider().padding(.leading, 38).opacity(0.06)
                }
            }

            footer
        }
        .padding(.vertical, 6)
        .onAppear { mgr.refresh() }
    }

    private func row(_ tweak: FinderTweaksManager.Tweak) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tweak.sfSymbol)
                .font(.system(size: 12, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(mgr.value(for: tweak) ? Color.cyan : .secondary)
                .frame(width: 18)

            Text(tweak.label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 6)

            Toggle("", isOn: Binding(
                get: { mgr.value(for: tweak) },
                set: { mgr.set($0, for: tweak) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .tint(.cyan)
            .disabled(mgr.isApplying)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            if mgr.isApplying {
                ProgressView().controlSize(.small).scaleEffect(0.55)
                Text("Relaunching Finder…")
            } else {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                Text("Each change relaunches Finder")
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
