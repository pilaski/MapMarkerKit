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
    /// A filled, bordered rounded square carrying a glyph, centred on the coordinate.
    case square
    /// A filled, bordered diamond (a square rotated 45°) carrying a glyph, centred on
    /// the coordinate.
    case diamond
    /// A filled disc inside a thick ring of the same colour, centred on the
    /// coordinate. Reads at postage-stamp size where a plain dot disappears,
    /// which is why it is the outline map's default.
    case ringedDot
    /// A ring with the map showing through it, centred on the coordinate.
    case ring
    /// A cross-hair with a small centre dot, centred on the coordinate — the
    /// technical look, and the one that hides least of what is under it.
    case crosshair

    public var id: String { rawValue }

    /// A short human-readable name for pickers and the style catalog.
    public var displayName: String {
        switch self {
        case .teardrop: return "Pin"
        case .circle:   return "Circle"
        case .dot:      return "Dot"
        case .balloon:  return "Balloon"
        case .square:   return "Square"
        case .diamond:  return "Diamond"
        case .ringedDot: return "Ringed dot"
        case .ring:     return "Ring"
        case .crosshair: return "Cross-hair"
        }
    }

    /// An SF Symbol that previews the shape in a picker or catalog row.
    public var systemImage: String {
        switch self {
        case .teardrop: return "mappin"
        case .circle:   return "mappin.circle.fill"
        case .dot:      return "smallcircle.filled.circle"
        case .balloon:  return "mappin.and.ellipse"
        case .square:   return "square.fill"
        case .diamond:  return "diamond.fill"
        case .ringedDot: return "smallcircle.filled.circle.fill"
        case .ring:     return "circle"
        case .crosshair: return "plus.viewfinder"
        }
    }

    /// Whether the shape carries an inner glyph (symbol or number).
    ///
    /// The three point shapes don't: their whole design is a mark small enough
    /// to sit on a coordinate without covering it, and a glyph inside one would
    /// be illegible at the size they are drawn.
    public var showsGlyph: Bool {
        switch self {
        case .dot, .ringedDot, .ring, .crosshair: return false
        default: return true
        }
    }

    /// Shapes that mark a point rather than carry content — the set an outline
    /// map offers, and the set that stays legible at a few millimetres.
    public static let pointMarkers: [MarkerShape] = [.ringedDot, .dot, .ring, .crosshair, .teardrop]

    /// Whether the shape's natural anchor is its bottom tip (so the map annotation
    /// should be `.bottom`-anchored) rather than its centre.
    public var isBottomAnchored: Bool { self == .teardrop || self == .balloon }

    /// Whether the shape exposes a distinct *secondary* attachment point for labels
    /// (e.g. the balloon's body centre) in addition to its base point.
    public var hasSecondaryAnchor: Bool { self == .teardrop || self == .balloon }
}
