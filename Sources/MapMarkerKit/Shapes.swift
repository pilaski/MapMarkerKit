import SwiftUI

// MARK: - Teardrop pin

/// The classic "map pin" teardrop outline: a round head on top tapering to a point
/// at the bottom that sits on the coordinate. Ported from the `TeardropMarkers`
/// playground (`TeardropShape2`) and exposed as a reusable `Shape`.
///
/// The shape is drawn inside its `rect`; the round head's diameter equals the
/// rect's width and the tip touches `rect.maxY`, so a view that frames it with the
/// pin's natural aspect ratio gets a correctly proportioned pin.
public struct TeardropPinShape: Shape {
    /// Higher = straighter side walls, more "pin-like" (clamped 0.2…0.98).
    public var sharpness: CGFloat
    /// Higher = longer lower tip (clamped 0.05…0.60).
    public var tipHeightRatio: CGFloat
    /// Width of the rounded bottom tip relative to total width (clamped 0…0.35).
    public var tipWidthRatio: CGFloat

    public init(sharpness: CGFloat = 0.65,
                tipHeightRatio: CGFloat = 0.38,
                tipWidthRatio: CGFloat = 0.06) {
        self.sharpness = sharpness
        self.tipHeightRatio = tipHeightRatio
        self.tipWidthRatio = tipWidthRatio
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        let sharpness = min(max(self.sharpness, 0.2), 0.98)
        let tipHeightRatio = min(max(self.tipHeightRatio, 0.05), 0.60)
        let tipWidthRatio = min(max(self.tipWidthRatio, 0.0), 0.35)

        let circleRadius = width / 2
        let circleCenter = CGPoint(x: rect.midX, y: rect.minY + circleRadius)

        let tipHalfWidth = max(0.5, (width * tipWidthRatio) / 2)
        let tipY = rect.maxY
        let leftTip = CGPoint(x: rect.midX - tipHalfWidth, y: tipY - 1)
        let rightTip = CGPoint(x: rect.midX + tipHalfWidth, y: tipY - 1)

        let shoulderY = circleCenter.y + circleRadius * 0.78
        let sidePull = max(4, width * (1.0 - sharpness) * 0.42)
        let curveDepth = height * tipHeightRatio
        let bottomRoundness = max(2, tipHalfWidth * 1.6)

        path.move(to: leftTip)
        path.addCurve(
            to: CGPoint(x: rect.minX, y: circleCenter.y),
            control1: CGPoint(x: rect.midX - sidePull, y: tipY - curveDepth),
            control2: CGPoint(x: rect.minX, y: shoulderY)
        )
        path.addArc(
            center: circleCenter,
            radius: circleRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: rightTip,
            control1: CGPoint(x: rect.maxX, y: shoulderY),
            control2: CGPoint(x: rect.midX + sidePull, y: tipY - curveDepth)
        )
        // A rounded bottom cap instead of a flat line.
        path.addCurve(
            to: leftTip,
            control1: CGPoint(x: rect.midX + tipHalfWidth, y: tipY + bottomRoundness),
            control2: CGPoint(x: rect.midX - tipHalfWidth, y: tipY + bottomRoundness)
        )
        path.closeSubpath()
        return path
    }

    /// The pin's natural height for a given width (taller than it is wide), used so
    /// callers can size the bounding box without distorting the outline.
    public static func height(forWidth width: CGFloat) -> CGFloat { width * 1.42 }

    /// The centre of the round head for a pin drawn in `size`, in the shape's local
    /// coordinate space. This is the natural anchor for a glyph and the "secondary"
    /// label attachment point.
    public static func headCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.width / 2)
    }
}

// MARK: - Balloon

/// A rounded-rectangle balloon body with a downward pointer at the bottom centre,
/// whose tip anchors on the coordinate. Kept as a reusable shape so the kit can
/// demonstrate attaching a label to a marker's *secondary* point (the balloon's
/// body centre) rather than its base point (the tip).
public struct BalloonShape: Shape {
    public var pointer: CGFloat
    public var cornerRadius: CGFloat

    /// The downward pointer's height as a fraction of the body width.
    public static let pointerRatio: CGFloat = 9.0 / 26.0
    /// The body's corner radius as a fraction of the body width.
    public static let cornerRatio: CGFloat = 11.0 / 26.0

    public init(pointer: CGFloat = 9, cornerRadius: CGFloat = 11) {
        self.pointer = pointer
        self.cornerRadius = cornerRadius
    }

    /// A balloon scaled from its body width, keeping the pointer and corner radius
    /// in proportion so the outline looks identical at any size.
    public init(bodyWidth: CGFloat) {
        self.pointer = bodyWidth * BalloonShape.pointerRatio
        self.cornerRadius = bodyWidth * BalloonShape.cornerRatio
    }

    public func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(x: rect.minX, y: rect.minY,
                              width: rect.width, height: rect.height - pointer)
        var path = Path(roundedRect: bodyRect, cornerRadius: cornerRadius, style: .continuous)
        let tipX = rect.midX
        let baseHalf = pointer * 0.85
        var tip = Path()
        tip.move(to: CGPoint(x: tipX - baseHalf, y: bodyRect.maxY - 0.5))
        tip.addQuadCurve(to: CGPoint(x: tipX, y: rect.maxY),
                         control: CGPoint(x: tipX - baseHalf * 0.15, y: bodyRect.maxY + pointer * 0.55))
        tip.addQuadCurve(to: CGPoint(x: tipX + baseHalf, y: bodyRect.maxY - 0.5),
                         control: CGPoint(x: tipX + baseHalf * 0.15, y: bodyRect.maxY + pointer * 0.55))
        tip.closeSubpath()
        path.addPath(tip)
        return path
    }
}
