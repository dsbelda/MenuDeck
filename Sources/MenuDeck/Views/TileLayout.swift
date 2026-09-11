import SwiftUI

/// How the module tiles are arranged on the main panel.
enum TileLayout: String, CaseIterable, Identifiable {
    /// Icon over a label, four to a row. The most legible, and the default.
    case grid
    /// Icons only, six to a row — half the height of `grid`.
    case icons
    /// One module per row, icon beside label. Reads like a native menu.
    case list
    /// A single icons-only strip that scrolls sideways. The smallest the panel
    /// can get: the tiles never take more than one row however many are on.
    case row

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .grid:  "Grid"
        case .icons: "Icons only"
        case .list:  "List"
        case .row:   "Single row"
        }
    }

    var sfSymbol: String {
        switch self {
        case .grid:  "square.grid.2x2"
        case .icons: "square.grid.3x3"
        case .list:  "list.bullet"
        case .row:   "rectangle.split.3x1"
        }
    }

    var columns: Int {
        switch self {
        case .grid:  4
        case .icons: 6
        case .list:  1
        case .row:   0   // not a grid
        }
    }
}

// MARK: – Tiles

/// Icon over a label.
struct ModuleGridTile: View {
    let module: any Module
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: module.sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? module.tintColor : .secondary)
                    .frame(height: 18)
                    .contentTransition(.symbolEffect(.replace))

                Text(module.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectionBackground(module: module, isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

/// Icon alone, in a square.
struct ModuleIconTile: View {
    let module: any Module
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: module.sfSymbol)
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? module.tintColor : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(selectionBackground(
                    module: module,
                    isSelected: isSelected,
                    isHovered: isHovered
                ))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        // Without labels the icon has to carry the whole name, so a tooltip is
        // the only thing standing in for it.
        .help(Text(module.name))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

/// Icon beside label, one per row.
struct ModuleListRow: View {
    let module: any Module
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: module.sfSymbol)
                    .font(.system(size: 12, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? module.tintColor : .secondary)
                    .frame(width: 18)

                Text(module.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isSelected ? 0 : -90))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(selectionBackground(
                module: module,
                isSelected: isSelected,
                isHovered: isHovered
            ))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

// MARK: – Shared selection chrome

@MainActor
@ViewBuilder
private func selectionBackground(
    module: any Module,
    isSelected: Bool,
    isHovered: Bool = false,
    cornerRadius: CGFloat = 8
) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(
            isSelected
                ? module.tintColor.opacity(0.14)
                : Color.primary.opacity(isHovered ? 0.05 : 0)
        )
}
