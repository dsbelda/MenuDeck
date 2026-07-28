import SwiftUI

struct ModuleSectionView: View {
    let module: any Module
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if isExpanded {
                module.makeContent()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal:   .opacity.combined(with: .move(edge: .top))
                        )
                    )
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(module.tintColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(module.tintColor.opacity(0.18), lineWidth: 0.5)
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.76), value: isExpanded)
    }

    private var sectionHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(module.tintColor.gradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: module.tintColor.opacity(0.35), radius: 5, y: 2)

                Image(systemName: module.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(module.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) {
                isExpanded.toggle()
            }
        }
    }
}
