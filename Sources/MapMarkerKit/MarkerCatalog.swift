import SwiftUI

/// The set of properties a marker style lets a user change. Shapes are fixed per
/// style, so it never includes the shape itself.
public struct MarkerCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let fillColor   = MarkerCapabilities(rawValue: 1 << 0)
    public static let glyphColor  = MarkerCapabilities(rawValue: 1 << 1)
    public static let strokeColor = MarkerCapabilities(rawValue: 1 << 2)
    public static let symbol      = MarkerCapabilities(rawValue: 1 << 3)
    public static let size        = MarkerCapabilities(rawValue: 1 << 4)
    public static let label       = MarkerCapabilities(rawValue: 1 << 5)

    /// A human-readable list of what this style lets the user change.
    public var descriptions: [String] {
        var out: [String] = []
        if contains(.fillColor)   { out.append("Marker color") }
        if contains(.symbol)      { out.append("Symbol") }
        if contains(.glyphColor)  { out.append("Symbol color") }
        if contains(.strokeColor) { out.append("Border color") }
        if contains(.size)        { out.append("Size") }
        if contains(.label)       { out.append("Label") }
        return out
    }
}

/// A predefined, reusable marker style with a name, the capabilities it exposes and
/// a default value. Build a concrete marker by starting from `defaultStyle` and
/// editing the capabilities the style advertises.
public struct MarkerStyleTemplate: Identifiable {
    public let id: String
    public let name: String
    public let shape: MarkerShape
    public let capabilities: MarkerCapabilities
    public let defaultStyle: MarkerStyle

    public init(id: String, name: String, shape: MarkerShape,
                capabilities: MarkerCapabilities, defaultStyle: MarkerStyle) {
        self.id = id
        self.name = name
        self.shape = shape
        self.capabilities = capabilities
        self.defaultStyle = defaultStyle
    }

    /// An SF Symbol that represents the style in a list.
    public var previewSymbol: String { shape.systemImage }

    /// A small live preview of the style's default look (sized for a list row).
    @ViewBuilder
    public func preview(number: Int? = 1) -> some View {
        MarkerView(style: defaultStyle, number: number)
    }
}

/// A predefined label style with a name, the properties it exposes and a default.
public struct LabelStyleTemplate: Identifiable {
    public let id: String
    public let name: String
    public let defaultStyle: MarkerLabelStyle
    /// A short description of what makes this label style distinct.
    public let summary: String

    public init(id: String, name: String, summary: String, defaultStyle: MarkerLabelStyle) {
        self.id = id
        self.name = name
        self.summary = summary
        self.defaultStyle = defaultStyle
    }

    /// A small live preview rendering a sample string in this style.
    @ViewBuilder
    public func preview(_ sample: String = "Label") -> some View {
        MarkerLabel(style: defaultStyle, primary: sample, secondary: sample)
    }
}

/// The kit's registry of available marker and label styles, with their capabilities
/// and previews. Hosts can present these to let users pick a starting style.
public enum MarkerCatalog {

    /// Every predefined marker style.
    public static let markerStyles: [MarkerStyleTemplate] = [
        MarkerStyleTemplate(
            id: "pin", name: "Pin", shape: .teardrop,
            capabilities: [.fillColor, .glyphColor, .symbol, .size, .label],
            defaultStyle: MarkerStyle(shape: .teardrop, symbol: .pin, fillColor: .purple,
                                      glyphColor: .white, size: 28,
                                      label: MarkerLabelStyle(placement: .bottom, distance: 4))),
        MarkerStyleTemplate(
            id: "circle", name: "Circle", shape: .circle,
            capabilities: [.fillColor, .glyphColor, .strokeColor, .symbol, .size, .label],
            defaultStyle: MarkerStyle(shape: .circle, symbol: .airplane, fillColor: .orange,
                                      glyphColor: .white, size: 22,
                                      label: MarkerLabelStyle(placement: .right))),
        MarkerStyleTemplate(
            id: "dot", name: "Dot", shape: .dot,
            capabilities: [.fillColor, .strokeColor, .size, .label],
            defaultStyle: MarkerStyle(shape: .dot, symbol: .none, fillColor: .red,
                                      glyphColor: .white, size: 12,
                                      label: MarkerLabelStyle(placement: .right))),
        MarkerStyleTemplate(
            id: "balloon", name: "Balloon", shape: .balloon,
            capabilities: [.fillColor, .glyphColor, .symbol, .label],
            defaultStyle: MarkerStyle(shape: .balloon, symbol: .star, fillColor: .teal,
                                      glyphColor: .white,
                                      label: MarkerLabelStyle(placement: .right, anchor: .secondary)))
    ]

    /// Every predefined label style.
    public static let labelStyles: [LabelStyleTemplate] = [
        LabelStyleTemplate(
            id: "pill", name: "Pill", summary: "Text on a rounded pill background.",
            defaultStyle: MarkerLabelStyle(shape: .pill)),
        LabelStyleTemplate(
            id: "rectangular", name: "Rectangular", summary: "Text on a rounded-rectangle background.",
            defaultStyle: MarkerLabelStyle(shape: .rectangular)),
        LabelStyleTemplate(
            id: "twoSegment", name: "Two-color segments",
            summary: "Two adjacent strings on two background colors.",
            defaultStyle: MarkerLabelStyle(twoSegment: true)),
        LabelStyleTemplate(
            id: "outlined", name: "Outlined caption",
            summary: "White text with a slim outline and no background, like a map caption.",
            defaultStyle: .caption)
    ]

    /// Looks up a marker style template by id.
    public static func markerStyle(id: String) -> MarkerStyleTemplate? {
        markerStyles.first { $0.id == id }
    }

    /// Looks up a label style template by id.
    public static func labelStyle(id: String) -> LabelStyleTemplate? {
        labelStyles.first { $0.id == id }
    }
}
