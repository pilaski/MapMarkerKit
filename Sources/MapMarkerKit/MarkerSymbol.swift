import SwiftUI

/// The glyph drawn inside a marker that supports one (`MarkerShape.showsGlyph`).
/// This is a *user-selectable* palette of common map symbols plus a sequence-number
/// option. Hosts that need an arbitrary SF Symbol can use `.custom(_:)`.
public enum MarkerSymbol: Hashable, Codable, Sendable {
    case none
    /// Draws the marker's sequence number (supplied at render time) instead of a glyph.
    case number
    case pin
    case airplane
    case star
    case flag
    case heart
    case dot
    case camera
    /// Any SF Symbol name not covered by the named cases.
    case custom(String)

    /// The named, user-pickable symbols (excludes `.custom`).
    public static var pickable: [MarkerSymbol] {
        [.none, .number, .pin, .airplane, .star, .flag, .heart, .dot, .camera]
    }

    /// A short human-readable name for pickers.
    public var displayName: String {
        switch self {
        case .none:     return "None"
        case .number:   return "Number"
        case .pin:      return "Pin"
        case .airplane: return "Airplane"
        case .star:     return "Star"
        case .flag:     return "Flag"
        case .heart:    return "Heart"
        case .dot:      return "Dot"
        case .camera:   return "Camera"
        case .custom(let name): return name
        }
    }

    /// `true` when the marker shows its sequence number rather than an SF Symbol.
    public var isNumber: Bool { self == .number }

    /// The SF Symbol name to draw, or `nil` for `.none`/`.number` (which draw nothing
    /// or a number, respectively).
    public var systemImage: String? {
        switch self {
        case .none, .number: return nil
        case .pin:      return "mappin"
        case .airplane: return "airplane"
        case .star:     return "star.fill"
        case .flag:     return "flag.fill"
        case .heart:    return "heart.fill"
        case .dot:      return "circle.fill"
        case .camera:   return "camera.fill"
        case .custom(let name): return name
        }
    }
}

// MARK: - Raw-value bridging

extension MarkerSymbol: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "none":     self = .none
        case "number":   self = .number
        case "pin":      self = .pin
        case "airplane": self = .airplane
        case "star":     self = .star
        case "flag":     self = .flag
        case "heart":    self = .heart
        case "dot":      self = .dot
        case "camera":   self = .camera
        default:
            guard !rawValue.isEmpty else { return nil }
            self = .custom(rawValue)
        }
    }

    /// A stable string suitable for persistence (mirrors the named cases; a custom
    /// symbol round-trips through its SF Symbol name).
    public var rawValue: String {
        switch self {
        case .none:     return "none"
        case .number:   return "number"
        case .pin:      return "pin"
        case .airplane: return "airplane"
        case .star:     return "star"
        case .flag:     return "flag"
        case .heart:    return "heart"
        case .dot:      return "dot"
        case .camera:   return "camera"
        case .custom(let name): return name
        }
    }
}

extension MarkerSymbol: Identifiable {
    public var id: String { rawValue }
}
