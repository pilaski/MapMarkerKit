import SwiftUI

/// The overall outline of a marker. Shapes are *predefined* by the kit and are not
/// meant to be user-editable — a marker style is built by picking one of these and
/// then customising its colours, symbol and label. Each case knows how it anchors
/// on the map and where its label-attachment points are.
public enum MarkerShape: String, CaseIterable, Identifiable, Codable, Sendable {
    /// The classic map pin (teardrop) whose tip sits on the coordinate.
    case teardrop
    /// A filled, bordered circle carrying a glyph, centred on the coordinate.
    case circle
    /// A small plain dot centred on the coordinate (no glyph).
    case dot
    /// A rounded-rectangle balloon whose pointer tip sits on the coordinate.
    case balloon

    public var id: String { rawValue }

    /// A short human-readable name for pickers and the style catalog.
    public var displayName: String {
        switch self {
        case .teardrop: return "Pin"
        case .circle:   return "Circle"
        case .dot:      return "Dot"
        case .balloon:  return "Balloon"
        }
    }

    /// An SF Symbol that previews the shape in a picker or catalog row.
    public var systemImage: String {
        switch self {
        case .teardrop: return "mappin"
        case .circle:   return "mappin.circle.fill"
        case .dot:      return "smallcircle.filled.circle"
        case .balloon:  return "mappin.and.ellipse"
        }
    }

    /// Whether the shape carries an inner glyph (symbol or number).
    public var showsGlyph: Bool { self != .dot }

    /// Whether the shape's natural anchor is its bottom tip (so the map annotation
    /// should be `.bottom`-anchored) rather than its centre.
    public var isBottomAnchored: Bool { self == .teardrop || self == .balloon }

    /// Whether the shape exposes a distinct *secondary* attachment point for labels
    /// (e.g. the balloon's body centre) in addition to its base point.
    public var hasSecondaryAnchor: Bool { self == .teardrop || self == .balloon }
}
