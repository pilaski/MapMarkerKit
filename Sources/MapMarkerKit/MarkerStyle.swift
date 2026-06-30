import SwiftUI
import CoreGraphics

/// A complete, renderable marker style: a predefined `shape` plus the user-editable
/// colours, symbol, size and an optional `label`. This is the value both the SwiftUI
/// `MarkerView` and the Core Graphics `MarkerRenderer` consume, so the live map and a
/// static export look identical.
public struct MarkerStyle: Equatable {
    /// The predefined outline (not user-editable).
    public var shape: MarkerShape
    /// The glyph drawn inside the shape (ignored when the shape has no glyph).
    public var symbol: MarkerSymbol
    public var fillColor: Color
    public var glyphColor: Color
    /// The border colour around the shape.
    public var strokeColor: Color
    /// The base dimension of the marker (diameter for circle/dot, head width for a
    /// pin, body width for a balloon). The pointer and corner radius scale with it.
    public var size: CGFloat
    /// Overrides for the shape's adjustable dimensions (e.g. a pin's tip length or a
    /// balloon's pointer). Empty means the shape draws at its natural defaults.
    public var customization: ShapeCustomization
    /// The label appearance, or `nil` for a marker that never shows a label. Whether
    /// a label actually draws also depends on whether text is supplied at render time.
    public var label: MarkerLabelStyle?

    public init(shape: MarkerShape,
                symbol: MarkerSymbol = .none,
                fillColor: Color = .orange,
                glyphColor: Color = .white,
                strokeColor: Color = .white,
                size: CGFloat = 26,
                customization: ShapeCustomization = ShapeCustomization(),
                label: MarkerLabelStyle? = nil) {
        self.shape = shape
        self.symbol = symbol
        self.fillColor = fillColor
        self.glyphColor = glyphColor
        self.strokeColor = strokeColor
        self.size = size
        self.customization = customization
        self.label = label
    }

    /// A guarded base dimension defending against a corrupted/zero persisted size.
    public var resolvedSize: CGFloat { max(4, size) }
}

// MARK: - Geometry

/// Layout geometry for a marker style, shared by the SwiftUI and Core Graphics
/// renderers so they place glyphs and labels identically.
public struct MarkerGeometry {
    /// The bounding size of the drawn shape.
    public let size: CGSize
    /// The shape's base point (tip of a pin/balloon, centre of a circle) in the
    /// shape's local coordinate space.
    public let basePoint: CGPoint
    /// The shape's secondary point (head of a pin, body centre of a balloon) — equal
    /// to `basePoint` for shapes without a secondary anchor.
    public let secondaryPoint: CGPoint
    /// The rect a `.base`-anchored label is laid out around (the full shape box).
    public let baseBox: CGRect
    /// The rect a `.secondary`-anchored label is laid out around (the head/body box).
    public let secondaryBox: CGRect
    /// The point and point size a glyph should be drawn at.
    public let glyphCenter: CGPoint
    public let glyphPointSize: CGFloat

    /// Computes the geometry for a style at a given highlight state.
    public static func make(for style: MarkerStyle, highlighted: Bool = false) -> MarkerGeometry {
        let base = style.resolvedSize
        switch style.shape {
        case .circle:
            let d = highlighted ? base * 1.25 : base
            let box = CGRect(x: 0, y: 0, width: d, height: d)
            let center = CGPoint(x: d / 2, y: d / 2)
            return MarkerGeometry(size: box.size, basePoint: center, secondaryPoint: center,
                                  baseBox: box, secondaryBox: box,
                                  glyphCenter: center, glyphPointSize: base * 0.55)
        case .dot:
            let d = highlighted ? base * 1.35 : base
            let box = CGRect(x: 0, y: 0, width: d, height: d)
            let center = CGPoint(x: d / 2, y: d / 2)
            return MarkerGeometry(size: box.size, basePoint: center, secondaryPoint: center,
                                  baseBox: box, secondaryBox: box,
                                  glyphCenter: center, glyphPointSize: 0)
        case .teardrop:
            let w = highlighted ? base * 1.18 : base
            let h = w * style.shape.value(of: "aspect", in: style.customization)
            let fullBox = CGRect(x: 0, y: 0, width: w, height: h)
            let headBox = CGRect(x: 0, y: 0, width: w, height: w)
            let tip = CGPoint(x: w / 2, y: h)
            let headCenter = CGPoint(x: w / 2, y: w / 2)
            return MarkerGeometry(size: fullBox.size, basePoint: tip, secondaryPoint: headCenter,
                                  baseBox: fullBox, secondaryBox: headBox,
                                  glyphCenter: headCenter, glyphPointSize: w * 0.42)
        case .balloon:
            let body = highlighted ? base * 1.15 : base
            let pointer = body * style.shape.value(of: "pointer", in: style.customization)
            let fullBox = CGRect(x: 0, y: 0, width: body, height: body + pointer)
            let bodyBox = CGRect(x: 0, y: 0, width: body, height: body)
            let tip = CGPoint(x: body / 2, y: body + pointer)
            let bodyCenter = CGPoint(x: body / 2, y: body / 2)
            return MarkerGeometry(size: fullBox.size, basePoint: tip, secondaryPoint: bodyCenter,
                                  baseBox: fullBox, secondaryBox: bodyBox,
                                  glyphCenter: bodyCenter, glyphPointSize: body * 0.5)
        }
    }

    /// The reference rect a label is laid out around for the given anchor.
    public func box(for anchor: LabelAnchor) -> CGRect {
        anchor == .secondary ? secondaryBox : baseBox
    }
}
