import SwiftUI

/// A marker whose face is a photograph.
///
/// Two variants, matching the two shapes it makes sense on: a **circle** whose
/// whole face is the picture, and a **pin** carrying the picture in the head
/// disc where the glyph would otherwise sit. Both carry a small badge showing
/// the waypoint's own symbol (or its number), because a round photograph on a
/// map is a wonderful thing to look at and a hopeless thing to identify — the
/// badge is what still says "this is a hotel" at a glance. It can be switched
/// off with `showsBadge`, since it is also the one thing covering part of the
/// picture.
///
/// **Not a `MarkerShape` case.** A shape is drawn by three things — this view,
/// `MarkerRenderer`'s Core Graphics path, and the geometry table — and a
/// photo marker needs an image the other two would have to be handed. Keeping
/// it a separate view means the existing shapes are untouched and every
/// exhaustive switch over `MarkerShape` still compiles. The style, geometry
/// and label machinery are all reused as they are.
public struct PhotoMarkerView: View {

    /// Which of the two photo treatments to draw.
    public enum Shape: String, CaseIterable, Identifiable, Codable, Sendable {
        /// The picture fills a bordered circle centred on the coordinate.
        case circle
        /// The picture sits in the head of a pin whose tip is on the coordinate.
        case pin

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .circle: return "Photo circle"
            case .pin: return "Photo pin"
            }
        }

        public var systemImage: String {
            switch self {
            case .circle: return "person.crop.circle"
            case .pin: return "mappin.circle"
            }
        }

        /// The plain marker shape this one is built on, so a caller can size
        /// and anchor a photo marker exactly like its non-photo twin.
        public var baseShape: MarkerShape {
            switch self {
            case .circle: return .circle
            case .pin: return .teardrop
            }
        }
    }

    let shape: Shape
    /// The picture. `nil` draws the ordinary glyph instead — a marker whose
    /// photo has been deleted from the library should still be a marker.
    let photo: Image?
    /// Fill, stroke, size, glyph colour and label all come from here, so a
    /// photo marker matches the rest of the map's styling.
    let style: MarkerStyle
    /// The symbol badged on the picture. Defaults to the style's own.
    var badgeSymbol: MarkerSymbol?
    var primaryText: String?
    var secondaryText: String?
    var number: Int?
    /// Whether to draw the badge at all.
    ///
    /// Defaults to on, because a round photograph is hard to identify without
    /// it — but the badge is also the only thing covering part of the picture,
    /// and someone who chose a photo marker precisely to see the photograph
    /// should be able to have all of it.
    var showsBadge: Bool
    var highlighted: Bool

    public init(shape: Shape,
                photo: Image?,
                style: MarkerStyle,
                badgeSymbol: MarkerSymbol? = nil,
                primaryText: String? = nil,
                secondaryText: String? = nil,
                number: Int? = nil,
                showsBadge: Bool = true,
                highlighted: Bool = false) {
        self.shape = shape
        self.photo = photo
        self.style = style
        self.badgeSymbol = badgeSymbol
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.number = number
        self.showsBadge = showsBadge
        self.highlighted = highlighted
    }

    /// The geometry of the plain shape this is built on, so a photo circle is
    /// exactly the size an ordinary circle would have been.
    private var geometry: MarkerGeometry {
        var base = style
        base.shape = shape.baseShape
        return MarkerGeometry.make(for: base, highlighted: highlighted)
    }

    private var fill: Color { highlighted ? .red : style.fillColor }
    private var symbol: MarkerSymbol { badgeSymbol ?? style.symbol }

    public var body: some View {
        let geo = geometry
        Group {
            switch shape {
            case .circle: circleBody(geo)
            case .pin: pinBody(geo)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .overlay(alignment: labelPlacement(in: geo).alignment) {
            if let label = style.label, hasLabelText {
                MarkerLabel(style: label, primary: primaryText, secondary: secondaryText)
                    .fixedSize()
                    .offset(labelPlacement(in: geo).offset)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: Shapes

    private func circleBody(_ geo: MarkerGeometry) -> some View {
        let diameter = geo.size.width
        let ring = max(1.5, style.resolvedSize * 0.1)
        return photoDisc(diameter: diameter, ringWidth: ring, glyphSize: geo.glyphPointSize)
            .overlay(alignment: .bottomTrailing) {
                badge(diameter: diameter * 0.42)
                    // Pushed out over the ring so it reads as attached to the
                    // marker rather than as something inside the picture.
                    .offset(x: diameter * 0.06, y: diameter * 0.06)
            }
            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
    }

    private func pinBody(_ geo: MarkerGeometry) -> some View {
        let width = geo.size.width
        let headDiameter = max(8, width * 0.6)
        let pin = TeardropPinShape(customization: style.customization)
        return ZStack {
            pin
                .fill(fill)
                .overlay(pin.stroke(style.strokeColor, lineWidth: max(1, width * 0.04)))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0.5, y: 1.5)
            photoDisc(diameter: headDiameter,
                      ringWidth: max(1, width * 0.03),
                      glyphSize: geo.glyphPointSize,
                      ringColor: style.glyphColor,
                      placeholderColor: fill)
                .overlay(alignment: .bottomTrailing) {
                    badge(diameter: headDiameter * 0.46)
                        .offset(x: headDiameter * 0.1, y: headDiameter * 0.1)
                }
                .position(geo.glyphCenter)
        }
    }

    /// The picture, clipped round, inside a ring. Falls back to the plain glyph
    /// on the marker's own fill when there is no picture.
    private func photoDisc(diameter: CGFloat,
                           ringWidth: CGFloat,
                           glyphSize: CGFloat,
                           ringColor: Color? = nil,
                           placeholderColor: Color? = nil) -> some View {
        let ring = ringColor ?? style.strokeColor
        return Circle()
            .fill(placeholderColor ?? fill)
            .overlay {
                if let photo {
                    photo
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    glyph(pointSize: glyphSize, color: style.glyphColor)
                }
            }
            .overlay(Circle().strokeBorder(ring, lineWidth: ringWidth))
            .frame(width: diameter, height: diameter)
    }

    /// The waypoint's own symbol, on a filled disc, so a photograph is still
    /// identifiable as a hotel or a viewpoint.
    @ViewBuilder
    private func badge(diameter: CGFloat) -> some View {
        if showsBadge, symbol.systemImage != nil || (symbol.isNumber && number != nil) {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(style.strokeColor, lineWidth: max(0.75, diameter * 0.08)))
                .overlay { glyph(pointSize: diameter * 0.6, color: style.glyphColor) }
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
        }
    }

    @ViewBuilder
    private func glyph(pointSize: CGFloat, color: Color) -> some View {
        if symbol.isNumber, let number {
            Text("\(number)")
                .font(.system(size: pointSize, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
        } else if let systemImage = symbol.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: pointSize, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: Label

    private var hasLabelText: Bool {
        (primaryText?.isEmpty == false) || (secondaryText?.isEmpty == false)
    }

    /// Mirrors `MarkerView.labelPlacement` — the label sits in the same place
    /// whether or not the marker carries a picture.
    private func labelPlacement(in geo: MarkerGeometry) -> (alignment: Alignment, offset: CGSize) {
        guard let label = style.label else { return (.center, .zero) }
        let ref = geo.box(for: label.anchor)
        let distance = label.distance
        let size = geo.size
        switch label.placement {
        case .right:
            return (.leading, CGSize(width: ref.maxX + distance, height: ref.midY - size.height / 2))
        case .left:
            return (.trailing, CGSize(width: (ref.minX - distance) - size.width,
                                      height: ref.midY - size.height / 2))
        case .top:
            return (.bottom, CGSize(width: ref.midX - size.width / 2,
                                    height: (ref.minY - distance) - size.height))
        case .bottom:
            return (.top, CGSize(width: ref.midX - size.width / 2, height: ref.maxY + distance))
        case .center:
            return (.center, CGSize(width: ref.midX - size.width / 2,
                                    height: ref.midY - size.height / 2))
        }
    }
}

#Preview("Photo markers") {
    let style = MarkerStyle(shape: .circle, symbol: .camera,
                            fillColor: .indigo, glyphColor: .white, strokeColor: .white, size: 44)
    return HStack(spacing: 28) {
        PhotoMarkerView(shape: .circle, photo: nil, style: style)
        PhotoMarkerView(shape: .pin, photo: nil, style: style)
        PhotoMarkerView(shape: .circle, photo: Image(systemName: "photo.fill"), style: style)
        PhotoMarkerView(shape: .pin, photo: Image(systemName: "photo.fill"), style: style)
    }
    .padding(40)
}

// MARK: - Core Graphics

public extension MarkerRenderer {

    /// Draws a photo marker into a `CGContext`, so one appears in an exported
    /// map image and not only on screen.
    ///
    /// The picture is a `CGImage` rather than a SwiftUI `Image` because that is
    /// the currency the rest of this file's drawing deals in — and because the
    /// caller has already had to decode the bytes to get here.
    ///
    /// Pass `nil` for the picture and this falls straight through to
    /// `drawMarker`: a marker whose photo could not be loaded should still be
    /// the marker it always was, in the right place, at the right size.
    static func drawPhotoMarker(at point: CGPoint,
                                shape: PhotoMarkerView.Shape,
                                photo: CGImage?,
                                style: MarkerStyle,
                                primary: String? = nil,
                                secondary: String? = nil,
                                number: Int? = nil,
                                highlighted: Bool = false,
                                in ctx: CGContext) {
        var base = style
        base.shape = shape.baseShape
        drawMarker(at: point, style: base, primary: primary, secondary: secondary,
                   number: number, highlighted: highlighted, in: ctx)

        guard let photo else { return }
        let geometry = MarkerGeometry.make(for: base, highlighted: highlighted)

        // `drawMarker` anchors the shape by its base point, so the picture goes
        // where the glyph just went — offset from the anchor by the same vector.
        let centre = CGPoint(x: point.x + geometry.glyphCenter.x - geometry.basePoint.x,
                             y: point.y + geometry.glyphCenter.y - geometry.basePoint.y)
        let diameter = shape == .circle
            ? geometry.size.width - max(1.5, base.resolvedSize * 0.1) * 2
            : max(8, geometry.size.width * 0.6) - max(1, geometry.size.width * 0.03) * 2
        let frame = CGRect(x: centre.x - diameter / 2, y: centre.y - diameter / 2,
                           width: diameter, height: diameter)

        ctx.saveGState()
        ctx.addEllipse(in: frame)
        ctx.clip()
        // Aspect-fill: a letterboxed photograph inside a circle reads as a
        // mistake, and the crop is what the on-screen marker shows too.
        let scale = max(frame.width / CGFloat(photo.width), frame.height / CGFloat(photo.height))
        let drawn = CGSize(width: CGFloat(photo.width) * scale,
                           height: CGFloat(photo.height) * scale)
        let target = CGRect(x: frame.midX - drawn.width / 2, y: frame.midY - drawn.height / 2,
                            width: drawn.width, height: drawn.height)
        // The context is top-left-origin and `draw` is not, so the image goes in
        // upside down without undoing the flip for the length of the draw.
        ctx.translateBy(x: 0, y: target.midY * 2)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(photo, in: target)
        ctx.restoreGState()
    }
}
