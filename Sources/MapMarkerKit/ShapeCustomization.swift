import SwiftUI
import CoreGraphics
import Combine

/// One adjustable dimension of a customizable shape, with the range it accepts and a
/// sensible default. Shapes advertise their parameters via
/// `MarkerShape.customizableParameters`, so a store or editor can build controls for
/// them generically without hard-coding each shape's knobs.
public struct ShapeParameter: Identifiable, Equatable, Sendable {
    /// A stable key used to read/write the value in a `ShapeCustomization`.
    public let id: String
    /// A short human-readable name for a slider or field.
    public let name: String
    /// The allowed range for the value (the editor should clamp to this).
    public let range: ClosedRange<CGFloat>
    /// The value used when a customization doesn't override this parameter.
    public let defaultValue: CGFloat

    public init(id: String, name: String, range: ClosedRange<CGFloat>, defaultValue: CGFloat) {
        self.id = id
        self.name = name
        self.range = range
        self.defaultValue = defaultValue
    }
}

/// A set of dimension overrides for a shape, keyed by `ShapeParameter.id`. An empty
/// customization means "use the shape's natural defaults", so it's safe to attach to
/// every `MarkerStyle`. Codable so hosts can persist user-defined shapes.
public struct ShapeCustomization: Equatable, Codable, Sendable {
    /// The overridden parameter values, keyed by parameter id. Unset keys fall back to
    /// the parameter's `defaultValue`.
    public var values: [String: CGFloat]

    public init(values: [String: CGFloat] = [:]) {
        self.values = values
    }

    /// Whether any parameter is overridden (otherwise the shape draws at its defaults).
    public var isEmpty: Bool { values.isEmpty }

    /// Reads or writes a single override.
    public subscript(_ id: String) -> CGFloat? {
        get { values[id] }
        set { values[id] = newValue }
    }
}

// MARK: - Shape parameters

public extension MarkerShape {

    /// The adjustable dimension parameters this shape exposes, at their default values.
    /// Circle and dot expose none (their only dimension is the marker size, handled by
    /// `MarkerStyle.size`); the pin and balloon expose their outline proportions.
    var customizableParameters: [ShapeParameter] {
        switch self {
        case .teardrop:
            return [
                ShapeParameter(id: "aspect",    name: "Height",     range: 1.1...1.8,   defaultValue: 1.42),
                ShapeParameter(id: "sharpness", name: "Sharpness",  range: 0.2...0.98,  defaultValue: 0.65),
                ShapeParameter(id: "tipHeight", name: "Tip length", range: 0.05...0.60, defaultValue: 0.38),
                ShapeParameter(id: "tipWidth",  name: "Tip width",  range: 0.0...0.35,  defaultValue: 0.06)
            ]
        case .balloon:
            return [
                ShapeParameter(id: "pointer", name: "Pointer length", range: 0.15...0.60, defaultValue: BalloonShape.pointerRatio),
                ShapeParameter(id: "corner",  name: "Corner radius",  range: 0.0...0.50,  defaultValue: BalloonShape.cornerRatio)
            ]
        case .circle, .dot:
            return []
        }
    }

    /// Whether the shape exposes adjustable dimensions beyond its size, i.e. whether it
    /// can be turned into a custom shape.
    var isCustomizable: Bool { !customizableParameters.isEmpty }

    /// Resolves a parameter's value from a customization: the override if present and in
    /// range, otherwise the parameter's default. Returns `0` for an unknown parameter id.
    func value(of id: String, in customization: ShapeCustomization) -> CGFloat {
        guard let param = customizableParameters.first(where: { $0.id == id }) else { return 0 }
        let raw = customization[id] ?? param.defaultValue
        return min(max(raw, param.range.lowerBound), param.range.upperBound)
    }
}

// MARK: - Shape construction from a customization

public extension TeardropPinShape {
    /// Builds a pin outline from a shape customization, reading the `sharpness`,
    /// `tipHeight` and `tipWidth` parameters (defaults fill in any that are unset).
    init(customization: ShapeCustomization) {
        self.init(
            sharpness:      MarkerShape.teardrop.value(of: "sharpness", in: customization),
            tipHeightRatio: MarkerShape.teardrop.value(of: "tipHeight", in: customization),
            tipWidthRatio:  MarkerShape.teardrop.value(of: "tipWidth",  in: customization))
    }
}

public extension BalloonShape {
    /// Builds a balloon scaled to `bodyWidth`, reading the `pointer` and `corner`
    /// proportions from a customization (defaults fill in any that are unset).
    init(bodyWidth: CGFloat, customization: ShapeCustomization) {
        let pointerRatio = MarkerShape.balloon.value(of: "pointer", in: customization)
        let cornerRatio  = MarkerShape.balloon.value(of: "corner",  in: customization)
        self.init(pointer: bodyWidth * pointerRatio, cornerRadius: bodyWidth * cornerRatio)
    }
}

// MARK: - Custom shapes & store

/// A user-defined shape: one of the kit's customizable base shapes plus a saved set of
/// dimension overrides and a name. Build a marker on top of it with `apply(to:)`.
public struct CustomMarkerShape: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// The predefined shape these overrides are based on.
    public var base: MarkerShape
    public var customization: ShapeCustomization

    public init(id: UUID = UUID(), name: String, base: MarkerShape, customization: ShapeCustomization) {
        self.id = id
        self.name = name
        self.base = base
        self.customization = customization
    }

    /// Returns a copy of `style` re-based on this custom shape (its base shape and saved
    /// dimensions), leaving the colours, symbol, size and label untouched.
    public func apply(to style: MarkerStyle) -> MarkerStyle {
        var copy = style
        copy.shape = base
        copy.customization = customization
        return copy
    }
}

/// An observable collection of user-defined shapes. Hosts keep one of these (e.g. as a
/// `@StateObject`) so a shape-modifier screen can save custom shapes that a marker
/// editor then offers. The kit ships the store; persistence is left to the host, but
/// `CustomMarkerShape` is `Codable` so it's easy to add.
public final class CustomShapeStore: ObservableObject {
    @Published public private(set) var shapes: [CustomMarkerShape]

    public init(shapes: [CustomMarkerShape] = []) {
        self.shapes = shapes
    }

    /// Adds a shape, or replaces the existing one with the same id.
    public func add(_ shape: CustomMarkerShape) {
        if let index = shapes.firstIndex(where: { $0.id == shape.id }) {
            shapes[index] = shape
        } else {
            shapes.append(shape)
        }
    }

    public func remove(_ shape: CustomMarkerShape) {
        shapes.removeAll { $0.id == shape.id }
    }

    public func remove(atOffsets offsets: IndexSet) {
        shapes.remove(atOffsets: offsets)
    }
}
