import SwiftUI

// MARK: – Design Metrics

enum DeckMetrics {
    /// Single source of truth for the popover width across header, tiles,
    /// expanded modules, and settings so panels never jitter when switching.
    static let panelWidth: CGFloat = 316

    /// Fixed viewport height for an open module so switching modules never
    /// resizes the popover window mid-interaction.
    static let moduleHeight: CGFloat = 276

    /// Fixed height for the scrollable settings sheet.
    static let settingsHeight: CGFloat = 400

    static let horizontalPadding: CGFloat = 12
    static let cardRadius: CGFloat = 11
    static let itemRadius: CGFloat = 8
    static let dividerOpacity: Double = 0.08
}

// MARK: – Hairline

struct DeckHairline: View {
    var leadingInset: CGFloat = 0
    var horizontalInset: CGFloat = 0

    var body: some View {
        Divider()
            .opacity(DeckMetrics.dividerOpacity)
            .padding(.leading, leadingInset)
            .padding(.horizontal, horizontalInset)
    }
}

// MARK: – Card Surfaces

/// Translucent Control Center–style card that adapts cleanly to macOS Tahoe's
/// Light (elevated translucent white) and Dark (luminous glass) appearances.
struct DeckCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    var radius: CGFloat = DeckMetrics.cardRadius
    var padding: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content()
            .padding(padding)
            .background(
                scheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.68),
                in: shape
            )
            .overlay(
                shape.strokeBorder(
                    scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.075),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: scheme == .dark ? .clear : Color.black.opacity(0.035),
                radius: 2,
                y: 1
            )
    }
}

/// A rounded card of stacked rows separated by crisp inset hairlines.
struct DeckGroupedList<Content: View>: View {
    var dividerInset: CGFloat = 38
    var radius: CGFloat = DeckMetrics.cardRadius
    @ViewBuilder let content: () -> Content

    var body: some View {
        DeckCard(radius: radius) {
            VStack(spacing: 0) {
                Group(subviews: content()) { rows in
                    ForEach(rows) { row in
                        row
                        if row.id != rows.last?.id {
                            DeckHairline(leadingInset: dividerInset)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: – Full-width Segmented Picker

/// Sleek full-width segmented control matching macOS Tahoe's pill chrome.
struct DeckSegmentedPicker<Selection: Hashable>: View {
    struct Segment: Identifiable {
        let id: Selection
        let title: String
    }

    @Environment(\.colorScheme) private var scheme
    @Binding var selection: Selection
    let segments: [Segment]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments) { segment in
                let isSelected = selection == segment.id
                Button {
                    withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                        selection = segment.id
                    }
                } label: {
                    Text(segment.title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .padding(.horizontal, 8)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                    .fill(scheme == .dark ? Color.white.opacity(0.14) : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                            .strokeBorder(
                                                scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                                                lineWidth: 0.5
                                            )
                                    )
                                    .shadow(
                                        color: Color.black.opacity(scheme == .dark ? 0.18 : 0.08),
                                        radius: 1.5,
                                        y: 0.5
                                    )
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            scheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 8.5, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                .strokeBorder(
                    scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: – Section Header

struct DeckSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var icon: String? = nil
    var tint: Color = .secondary
    @ViewBuilder let trailing: () -> Trailing

    init(
        _ title: LocalizedStringKey,
        icon: String? = nil,
        tint: Color = .secondary,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer(minLength: 4)
            trailing()
        }
    }
}

extension DeckSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, icon: String? = nil, tint: Color = .secondary) {
        self.init(title, icon: icon, tint: tint) { EmptyView() }
    }
}

// MARK: – Icon Badge

/// Tinted squircle icon badge modeled after macOS System Settings & Control Center.
struct DeckIconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 24
    var iconSize: CGFloat = 11
    var isActive: Bool = true
    var cornerRadius: CGFloat? = nil

    private var radius: CGFloat { cornerRadius ?? (size * 0.28) }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: iconSize, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
            .frame(width: size, height: size)
            .background(
                isActive ? tint.opacity(0.15) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}

// MARK: – Interactive Buttons & Rows

/// Tactile press-scale button style without AppKit's focus bezel.
struct DeckPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Compact circular/squircle icon button with hover and press feedback.
struct DeckIconButton: View {
    let symbol: String
    var size: CGFloat = 24
    var iconSize: CGFloat = 11
    var weight: Font.Weight = .medium
    var tint: Color = .secondary
    var hoverTint: Color? = nil
    var restingFill: Double = 0.06
    var isCircular: Bool = true
    var cornerRadius: CGFloat = 7
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: weight))
                .foregroundStyle(isHovered ? (hoverTint ?? .primary) : tint)
                .frame(width: size, height: size)
                .background {
                    if isCircular {
                        Circle().fill(Color.primary.opacity(isHovered ? 0.12 : restingFill))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(isHovered ? 0.12 : restingFill))
                    }
                }
                .contentTransition(.symbolEffect(.replace))
                .contentShape(Rectangle())
        }
        .buttonStyle(DeckPressStyle(scale: 0.93))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// Action pill / rounded button with consistent hover, border, and press feel.
struct DeckActionButton<LabelContent: View>: View {
    enum Variant {
        case neutral
        case tinted(Color)
        case solid(Color)
    }

    @Environment(\.colorScheme) private var scheme

    let variant: Variant
    var cornerRadius: CGFloat = DeckMetrics.itemRadius
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 7
    var fullWidth: Bool = false
    let action: () -> Void
    @ViewBuilder let label: () -> LabelContent

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
                .foregroundStyle(foreground)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(
                    background,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(DeckPressStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var foreground: Color {
        switch variant {
        case .neutral:           return isHovered ? .primary : .secondary
        case .tinted(let color): return color
        case .solid:             return .white
        }
    }

    private var background: Color {
        switch variant {
        case .neutral:
            return scheme == .dark
                ? Color.white.opacity(isHovered ? 0.11 : 0.065)
                : Color.white.opacity(isHovered ? 0.92 : 0.72)
        case .tinted(let color):
            return color.opacity(isHovered ? 0.22 : 0.14)
        case .solid(let color):
            return color.opacity(isHovered ? 0.90 : 1.0)
        }
    }

    private var border: Color {
        switch variant {
        case .neutral:
            return scheme == .dark
                ? Color.white.opacity(isHovered ? 0.14 : 0.08)
                : Color.black.opacity(isHovered ? 0.14 : 0.09)
        case .tinted(let color):
            return color.opacity(isHovered ? 0.38 : 0.26)
        case .solid:
            return Color.white.opacity(0.15)
        }
    }
}

/// Inset hover row container — matches macOS Sequoia/Tahoe native menu highlights.
struct DeckHoverRow<Content: View>: View {
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 6
    var horizontalInset: CGFloat = 6
    var isSelected: Bool = false
    var tint: Color = .accentColor
    var isInteractive: Bool = true
    @ViewBuilder let content: (_ isHovered: Bool) -> Content

    @State private var isHovered = false

    var body: some View {
        content(isHovered)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                rowBackground,
                in: RoundedRectangle(cornerRadius: DeckMetrics.itemRadius, style: .continuous)
            )
            .padding(.horizontal, horizontalInset)
            .contentShape(Rectangle())
            .onHover { hovering in
                if isInteractive { isHovered = hovering }
            }
            .animation(.easeOut(duration: 0.10), value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected {
            return tint.opacity(isHovered ? 0.18 : 0.13)
        }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }
}

// MARK: – Progress Bar

struct DeckProgressBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 6

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.085))
                if clamped > 0.001 {
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(height, geo.size.width * clamped))
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: – Status Banner

struct DeckStatusBanner<Trailing: View>: View {
    @Environment(\.colorScheme) private var scheme

    let icon: String
    let tint: Color
    let title: Text
    var subtitle: Text? = nil
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        tint: Color,
        title: Text,
        subtitle: Text? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .padding(.top, subtitle == nil ? 0 : 1)

            VStack(alignment: .leading, spacing: 1.5) {
                title
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    subtitle
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            trailing()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            bannerFill,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(bannerBorder, lineWidth: 0.5)
        )
    }

    private var bannerFill: Color {
        if tint == .secondary {
            return scheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.55)
        }
        return tint.opacity(scheme == .dark ? 0.10 : 0.11)
    }

    private var bannerBorder: Color {
        if tint == .secondary {
            return scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
        }
        return tint.opacity(0.24)
    }
}

extension DeckStatusBanner where Trailing == EmptyView {
    init(icon: String, tint: Color, title: Text, subtitle: Text? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: – Empty State

struct DeckEmptyState<Action: View>: View {
    let symbol: String
    var tint: Color = .secondary
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var minHeight: CGFloat = 180
    @ViewBuilder let action: () -> Action

    init(
        symbol: String,
        tint: Color = .secondary,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        minHeight: CGFloat = 180,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.minHeight = minHeight
        self.action = action
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                .frame(width: 42, height: 42)
                .background(
                    (tint == .secondary ? Color.primary : tint).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.88))
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 18)
                }
            }

            action()
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

extension DeckEmptyState where Action == EmptyView {
    init(
        symbol: String,
        tint: Color = .secondary,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        minHeight: CGFloat = 180
    ) {
        self.init(
            symbol: symbol,
            tint: tint,
            title: title,
            subtitle: subtitle,
            minHeight: minHeight
        ) { EmptyView() }
    }
}

// MARK: – Module Toolbar

struct DeckModuleToolbar<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                leading()
                Spacer(minLength: 4)
                trailing()
            }
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.vertical, 7)

            DeckHairline()
        }
    }
}
