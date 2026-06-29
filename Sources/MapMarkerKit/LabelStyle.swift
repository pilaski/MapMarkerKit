import SwiftUI

/// Where a marker's label sits relative to its attachment point.
public enum LabelPlacement: String, CaseIterable, Identifiable, Codable, Sendable {
    case right
    case left
    case top
    case bottom
    case center

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .right:  return "Right"
        case .left:   return "Left"
        case .top:    return "Top"
        case .bottom: return "Bottom"
        case .center: return "Centered"
        }
    }
}

/// Which point of a marker a label is attached to.
public enum LabelAnchor: String, CaseIterable, Identifiable, Codable, Sendable {
    /// The marker's base point: the centre of a circular marker or the tip of a pin.
    case base
    /// A secondary point, e.g. the head of a pin or the centre of a balloon body.
    /// Falls back to the base point for shapes without a secondary anchor.
    case secondary

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .base:      return "Base point"
        case .secondary: return "Marker body"
        }
    }
}

/// The outline of a label's background box.
public enum LabelShape: String, CaseIterable, Identifiable, Codable, Sendable {
    case pill
    case rectangular
    /// No background box — useful with `LabelTextStyle.outlined` for free-floating
    /// captions (e.g. white text with a slim dark outline).
    case none

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pill:        return "Pill"
        case .rectangular: return "Rectangular"
        case .none:        return "No background"
        }
    }

    /// The clip shape for the background box (a zero-radius rectangle for `.none`,
    /// though `.none` callers normally skip the background entirely).
    public var clipShape: AnyShape {
        switch self {
        case .pill:        return AnyShape(Capsule())
        case .rectangular: return AnyShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        case .none:        return AnyShape(Rectangle())
        }
    }
}

/// How the label's text itself is rendered.
public enum LabelTextStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    /// A single text colour.
    case plain
    /// Two-colour text: the fill colour surrounded by a slim second outline colour
    /// (e.g. white text with a thin black outline, like map captions).
    case outlined

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .plain:    return "Plain"
        case .outlined: return "Outlined"
        }
    }
}

/// The full appearance of a marker label: where it attaches, how its text is drawn
/// and how its background box looks. Content (the actual strings) is supplied at
/// render time, so one `LabelStyle` can be reused across many markers.
public struct LabelStyle: Equatable {
    // Placement
    public var placement: LabelPlacement
    public var anchor: LabelAnchor
    public var distance: CGFloat

    // Text
    public var fontSize: CGFloat
    public var fontWeight: Font.Weight
    public var textColor: Color
    public var textStyle: LabelTextStyle
    /// The surrounding colour used when `textStyle == .outlined`.
    public var outlineColor: Color
    /// The outline thickness used when `textStyle == .outlined`.
    public var outlineWidth: CGFloat

    // Background
    public var shape: LabelShape
    public var backgroundColor: Color
    /// When `true`, the primary and secondary strings are drawn as two adjacent
    /// coloured segments (`backgroundColor` then `secondaryColor`).
    public var twoSegment: Bool
    public var secondaryColor: Color

    public init(placement: LabelPlacement = .right,
                anchor: LabelAnchor = .base,
                distance: CGFloat = 5,
                fontSize: CGFloat = 11,
                fontWeight: Font.Weight = .semibold,
                textColor: Color = .primary,
                textStyle: LabelTextStyle = .plain,
                outlineColor: Color = .black,
                outlineWidth: CGFloat = 1,
                shape: LabelShape = .pill,
                backgroundColor: Color = .white.opacity(0.9),
                twoSegment: Bool = false,
                secondaryColor: Color = .orange.opacity(0.9)) {
        self.placement = placement
        self.anchor = anchor
        self.distance = distance
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.textStyle = textStyle
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
        self.shape = shape
        self.backgroundColor = backgroundColor
        self.twoSegment = twoSegment
        self.secondaryColor = secondaryColor
    }

    /// A SwiftUI font matching the style's size and weight.
    public var font: Font { .system(size: fontSize, weight: fontWeight) }

    /// A caption preset: white outlined text with no background box (the look of the
    /// app's existing map captions).
    public static let caption = LabelStyle(
        placement: .bottom, anchor: .base, distance: 3,
        fontSize: 12, fontWeight: .semibold,
        textColor: .white, textStyle: .outlined, outlineColor: .black, outlineWidth: 1,
        shape: .none, backgroundColor: .clear)
}
