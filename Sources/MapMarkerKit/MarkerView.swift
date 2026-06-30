import SwiftUI

/// The single SwiftUI view that draws any `MarkerStyle`: the predefined shape, its
/// glyph (symbol or sequence number) and an attached label. Use it directly inside a
/// `MapKit` `Annotation`, or anywhere a marker preview is needed.
public struct MarkerView: View {
    let style: MarkerStyle
    /// The primary label text (e.g. a code or name). `nil` hides the label.
    var primaryText: String?
    /// The secondary label text, shown as a second segment for two-segment labels.
    var secondaryText: String?
    /// The sequence number drawn when the symbol is `.number`.
    var number: Int?
    /// Highlight state (e.g. a selected marker): tinted red and enlarged.
    var highlighted: Bool

    public init(style: MarkerStyle,
                primaryText: String? = nil,
                secondaryText: String? = nil,
                number: Int? = nil,
                highlighted: Bool = false) {
        self.style = style
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.number = number
        self.highlighted = highlighted
    }

    private var fill: Color { highlighted ? .red : style.fillColor }

    public var body: some View {
        let geo = MarkerGeometry.make(for: style, highlighted: highlighted)
        let placement = labelPlacement(in: geo)
        shapeView(geo)
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: placement.alignment) {
                if style.label != nil, hasLabelText {
                    MarkerLabel(style: style.label!, primary: primaryText, secondary: secondaryText)
                        .fixedSize()
                        .offset(placement.offset)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: Label placement

    private var hasLabelText: Bool {
        (primaryText?.isEmpty == false) || (secondaryText?.isEmpty == false)
    }

    /// The overlay alignment + offset that positions the label outside the chosen
    /// anchor box at the requested distance. Mirrors `MarkerRenderer.labelOrigin`.
    private func labelPlacement(in geo: MarkerGeometry) -> (alignment: Alignment, offset: CGSize) {
        guard let label = style.label else { return (.center, .zero) }
        let ref = geo.box(for: label.anchor)
        let dist = label.distance
        let size = geo.size
        switch label.placement {
        case .right:
            return (.leading, CGSize(width: ref.maxX + dist, height: ref.midY - size.height / 2))
        case .left:
            return (.trailing, CGSize(width: (ref.minX - dist) - size.width, height: ref.midY - size.height / 2))
        case .top:
            return (.bottom, CGSize(width: ref.midX - size.width / 2, height: (ref.minY - dist) - size.height))
        case .bottom:
            return (.top, CGSize(width: ref.midX - size.width / 2, height: ref.maxY + dist))
        case .center:
            return (.center, CGSize(width: ref.midX - size.width / 2, height: ref.midY - size.height / 2))
        }
    }

    // MARK: Shapes

    @ViewBuilder
    private func shapeView(_ geo: MarkerGeometry) -> some View {
        switch style.shape {
        case .teardrop: teardropBody(geo)
        case .circle:   circleBody(geo)
        case .dot:      dotBody(geo)
        case .balloon:  balloonBody(geo)
        }
    }

    @ViewBuilder
    private func glyph(pointSize: CGFloat, color: Color) -> some View {
        if style.symbol.isNumber, let number {
            Text("\(number)")
                .font(.system(size: pointSize, weight: .bold))
                .foregroundStyle(color)
        } else if let symbol = style.symbol.systemImage {
            Image(systemName: symbol)
                .font(.system(size: pointSize, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // A coloured pin with a light head disc; the symbol reads in the pin's fill colour.
    private func teardropBody(_ geo: MarkerGeometry) -> some View {
        let w = geo.size.width
        let headDiameter = max(8, w * 0.6)
        return ZStack {
            TeardropPinShape()
                .fill(fill)
                .overlay(TeardropPinShape().stroke(style.strokeColor, lineWidth: max(1, w * 0.04)))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0.5, y: 1.5)
            Circle()
                .fill(style.glyphColor)
                .frame(width: headDiameter, height: headDiameter)
                .overlay { glyph(pointSize: geo.glyphPointSize, color: fill) }
                .position(geo.glyphCenter)
        }
    }

    private func circleBody(_ geo: MarkerGeometry) -> some View {
        let d = geo.size.width
        return Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(style.strokeColor, lineWidth: max(1, style.resolvedSize * 0.1)))
            .overlay { glyph(pointSize: geo.glyphPointSize, color: style.glyphColor) }
            .frame(width: d, height: d)
            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
    }

    private func dotBody(_ geo: MarkerGeometry) -> some View {
        let d = geo.size.width
        return Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(style.strokeColor, lineWidth: 1.5))
            .frame(width: d, height: d)
            .shadow(radius: 1)
    }

    private func balloonBody(_ geo: MarkerGeometry) -> some View {
        let shape = BalloonShape(bodyWidth: geo.size.width)
        let stroke = max(1, geo.size.width * 0.058)
        return ZStack {
            shape
                .fill(fill)
                .overlay(shape.stroke(style.strokeColor, lineWidth: stroke))
                .shadow(radius: 1.5)
            glyph(pointSize: geo.glyphPointSize, color: style.glyphColor)
                .position(geo.glyphCenter)
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 40) {
        MarkerView(style: MarkerStyle(shape: .teardrop, symbol: .pin, fillColor: .purple,
                                      label: MarkerLabelStyle(placement: .bottom)),
                   primaryText: "Berlin")
        MarkerView(style: MarkerStyle(shape: .circle, symbol: .airplane, fillColor: .orange, size: 22,
                                      label: MarkerLabelStyle(placement: .right, twoSegment: true)),
                   primaryText: "HAM", secondaryText: "Hamburg")
        MarkerView(style: MarkerStyle(shape: .teardrop, symbol: .number, fillColor: .blue,
                                      label: MarkerLabelStyle(placement: .top, anchor: .secondary,
                                                        textColor: .white, textStyle: .outlined, shape: .none)),
                   primaryText: "Caption", number: 3)
    }
    .padding(40)
}
#endif
