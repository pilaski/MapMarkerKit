import SwiftUI
import CoreGraphics

/// Core Graphics rendering of markers and labels that mirrors the SwiftUI `MarkerView`,
/// so a static export (snapshot, thumbnail, share image) matches the live map. Hosts
/// draw into their own `CGContext`; the kit owns the marker/label geometry and styling.
public enum MarkerRenderer {

    /// Draws a marker at `point` (the marker's base point: a pin/balloon tip or a
    /// circle's centre) honouring its style, glyph and optional label.
    public static func drawMarker(at point: CGPoint,
                                  style: MarkerStyle,
                                  primary: String? = nil,
                                  secondary: String? = nil,
                                  number: Int? = nil,
                                  highlighted: Bool = false,
                                  in ctx: CGContext) {
        // Labels and SF Symbol glyphs render through AppKit/UIKit calls that take
        // no context argument, so `ctx` has to be the *ambient* one for the length
        // of the draw. On iOS a `UIGraphicsImageRenderer` caller already arranged
        // that; on macOS nothing does, and text would silently not appear.
        PlatformGraphics.withContext(ctx) {
            draw(at: point, style: style, primary: primary, secondary: secondary,
                 number: number, highlighted: highlighted, in: ctx)
        }
    }

    private static func draw(at point: CGPoint,
                             style: MarkerStyle,
                             primary: String?,
                             secondary: String?,
                             number: Int?,
                             highlighted: Bool,
                             in ctx: CGContext) {
        let geo = MarkerGeometry.make(for: style, highlighted: highlighted)
        // Translate so the geometry's base point lands on `point`.
        let origin = CGPoint(x: point.x - geo.basePoint.x, y: point.y - geo.basePoint.y)
        let fill = highlighted ? PlatformColor.red : PlatformColor(style.fillColor)
        let stroke = PlatformColor(style.strokeColor)
        let glyphColor = PlatformColor(style.glyphColor)

        switch style.shape {
        case .circle:
            drawCircle(in: geo.baseBox.offsetBy(dx: origin.x, dy: origin.y),
                       fill: fill, stroke: stroke, borderRatio: 0.18, in: ctx)
            drawGlyph(style.symbol, at: shift(geo.glyphCenter, by: origin),
                      pointSize: geo.glyphPointSize, color: glyphColor, number: number, in: ctx)
        case .dot:
            drawCircle(in: geo.baseBox.offsetBy(dx: origin.x, dy: origin.y),
                       fill: fill, stroke: stroke, borderRatio: 0.16, in: ctx)
        case .square:
            let rect = geo.baseBox.offsetBy(dx: origin.x, dy: origin.y)
            let path = Path(roundedRect: rect, cornerRadius: 3)
            fillAndBorder(path, fill: fill, stroke: stroke,
                          lineWidth: max(1, geo.size.width * 0.1), in: ctx)
            drawGlyph(style.symbol, at: shift(geo.glyphCenter, by: origin),
                      pointSize: geo.glyphPointSize, color: glyphColor, number: number, in: ctx)
        case .diamond:
            let rect = geo.baseBox.offsetBy(dx: origin.x, dy: origin.y)
            let path = DiamondShape().path(in: rect)
            fillAndBorder(path, fill: fill, stroke: stroke,
                          lineWidth: max(1, geo.size.width * 0.1), in: ctx)
            drawGlyph(style.symbol, at: shift(geo.glyphCenter, by: origin),
                      pointSize: geo.glyphPointSize, color: glyphColor, number: number, in: ctx)
        case .teardrop:
            let rect = CGRect(origin: origin, size: geo.size)
            let path = TeardropPinShape(customization: style.customization).path(in: rect)
            fillAndStroke(path, fill: fill, stroke: stroke, lineWidth: max(1, geo.size.width * 0.04), in: ctx)
            // The light head disc, with the glyph (if any) reading in the pin's fill.
            let headD = max(8, geo.size.width * 0.6)
            let headCenter = shift(geo.glyphCenter, by: origin)
            let headRect = CGRect(x: headCenter.x - headD / 2, y: headCenter.y - headD / 2,
                                  width: headD, height: headD)
            ctx.saveGState()
            ctx.setFillColor(glyphColor.cgColor)
            ctx.fillEllipse(in: headRect)
            ctx.restoreGState()
            drawGlyph(style.symbol, at: headCenter, pointSize: geo.glyphPointSize,
                      color: fill, number: number, in: ctx)
        case .balloon:
            let rect = CGRect(origin: origin, size: geo.size)
            let path = BalloonShape(bodyWidth: geo.size.width, customization: style.customization).path(in: rect)
            fillAndStroke(path, fill: fill, stroke: stroke, lineWidth: max(1, geo.size.width * 0.058), in: ctx)
            drawGlyph(style.symbol, at: shift(geo.glyphCenter, by: origin),
                      pointSize: geo.glyphPointSize, color: glyphColor, number: number, in: ctx)
        }

        // The label, placed relative to the chosen anchor box (in absolute coords).
        if let label = style.label {
            let parts = labelParts(style: label, primary: primary, secondary: secondary)
            if !parts.isEmpty {
                let refBox = geo.box(for: label.anchor).offsetBy(dx: origin.x, dy: origin.y)
                drawLabel(label, parts: parts, around: refBox, in: ctx)
            }
        }
    }

    // MARK: - Label drawing

    private static let labelPad: CGFloat = 3

    private static func labelParts(style: MarkerLabelStyle, primary: String?, secondary: String?) -> [String] {
        [primary, style.twoSegment ? secondary : nil].compactMap { $0 }.filter { !$0.isEmpty }
    }

    private static func labelFont(_ style: MarkerLabelStyle) -> PlatformFont {
        PlatformFont.systemFont(ofSize: max(8, style.fontSize), weight: .semibold)
    }

    private static func drawLabel(_ style: MarkerLabelStyle, parts: [String],
                                  around refBox: CGRect, in ctx: CGContext) {
        let font = labelFont(style)
        let hasBackground = style.shape != .none
        // Outlined text bleeds ~outlineWidth past the glyphs, so grow the box to keep
        // the outline from touching the background edge.
        let outlinePad: CGFloat = style.textStyle == .outlined ? max(0.5, style.outlineWidth) : 0
        let pad = hasBackground ? labelPad + outlinePad : 0

        var totalWidth: CGFloat = 0
        var height: CGFloat = 0
        for part in parts {
            let s = (part as NSString).size(withAttributes: [.font: font])
            totalWidth += s.width + pad * 2
            height = max(height, s.height + pad * 2)
        }
        let size = CGSize(width: totalWidth, height: height)
        let origin = labelOrigin(placement: style.placement, distance: style.distance,
                                 refBox: refBox, labelSize: size)

        let textColor = PlatformColor(style.textColor)
        let backgrounds = style.twoSegment && parts.count == 2
            ? [PlatformColor(style.backgroundColor), PlatformColor(style.secondaryColor)]
            : [PlatformColor(style.backgroundColor)]

        var x = origin.x
        for (i, part) in parts.enumerated() {
            let textSize = (part as NSString).size(withAttributes: [.font: font])
            let box = CGRect(x: x, y: origin.y, width: textSize.width + pad * 2, height: textSize.height + pad * 2)
            if hasBackground {
                let bg = backgrounds[min(i, backgrounds.count - 1)]
                let radius: CGFloat = style.shape == .pill ? box.height / 2 : 3
                ctx.saveGState()
                ctx.setFillColor(bg.cgColor)
                ctx.addPath(CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius,
                                   transform: nil))
                ctx.fillPath()
                ctx.restoreGState()
            }
            let textOrigin = CGPoint(x: x + pad, y: box.minY + pad)
            drawText(part, at: textOrigin, font: font, style: style, textColor: textColor, in: ctx)
            x += box.width
        }
    }

    private static func drawText(_ text: String, at point: CGPoint, font: PlatformFont,
                                 style: MarkerLabelStyle, textColor: PlatformColor, in ctx: CGContext) {
        let ns = text as NSString
        switch style.textStyle {
        case .plain:
            ns.draw(at: point, withAttributes: [.font: font, .foregroundColor: textColor])
        case .outlined:
            // A negative stroke width tells UIKit to both fill and stroke the glyphs,
            // giving the fill colour a surrounding outline in one pass.
            let width = max(0.5, style.outlineWidth)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .strokeColor: PlatformColor(style.outlineColor),
                .strokeWidth: -width / font.pointSize * 100
            ]
            ns.draw(at: point, withAttributes: attrs)
        }
    }

    /// The top-left origin for a label placed around `refBox`.
    private static func labelOrigin(placement: LabelPlacement, distance: CGFloat,
                                    refBox: CGRect, labelSize: CGSize) -> CGPoint {
        switch placement {
        case .right:  return CGPoint(x: refBox.maxX + distance, y: refBox.midY - labelSize.height / 2)
        case .left:   return CGPoint(x: refBox.minX - distance - labelSize.width, y: refBox.midY - labelSize.height / 2)
        case .top:    return CGPoint(x: refBox.midX - labelSize.width / 2, y: refBox.minY - distance - labelSize.height)
        case .bottom: return CGPoint(x: refBox.midX - labelSize.width / 2, y: refBox.maxY + distance)
        case .center: return CGPoint(x: refBox.midX - labelSize.width / 2, y: refBox.midY - labelSize.height / 2)
        }
    }

    // MARK: - Primitives

    private static func shift(_ p: CGPoint, by o: CGPoint) -> CGPoint {
        CGPoint(x: p.x + o.x, y: p.y + o.y)
    }

    private static func drawCircle(in rect: CGRect, fill: PlatformColor, stroke: PlatformColor,
                                   borderRatio: CGFloat, in ctx: CGContext) {
        let border = max(1, rect.width / 2 * borderRatio)
        ctx.saveGState()
        ctx.setFillColor(stroke.cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -border, dy: -border))
        ctx.setFillColor(fill.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()
    }

    private static func fillAndStroke(_ path: Path, fill: PlatformColor, stroke: PlatformColor,
                                      lineWidth: CGFloat, in ctx: CGContext) {
        let cg = path.cgPath
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: PlatformColor.black.withAlphaComponent(0.25).cgColor)
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(cg); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addPath(cg); ctx.strokePath()
        ctx.restoreGState()
    }

    /// Fills `path` then strokes its outline centred on the edge (no drop shadow),
    /// giving a bordered shape like the SwiftUI `strokeBorder` look. Used by the
    /// centred square / diamond markers.
    private static func fillAndBorder(_ path: Path, fill: PlatformColor, stroke: PlatformColor,
                                      lineWidth: CGFloat, in ctx: CGContext) {
        let cg = path.cgPath
        ctx.saveGState()
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(cg); ctx.fillPath()
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addPath(cg); ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawGlyph(_ symbol: MarkerSymbol, at point: CGPoint,
                                  pointSize: CGFloat, color: PlatformColor, number: Int?, in ctx: CGContext) {
        if symbol.isNumber, let number {
            let font = PlatformFont.systemFont(ofSize: pointSize * 1.05, weight: .bold)
            let ns = "\(number)" as NSString
            let s = ns.size(withAttributes: [.font: font])
            ns.draw(at: CGPoint(x: point.x - s.width / 2, y: point.y - s.height / 2),
                    withAttributes: [.font: font, .foregroundColor: color])
            return
        }
        guard let name = symbol.systemImage,
              let image = symbolImage(name, pointSize: pointSize, color: color) else { return }
        image.draw(in: CGRect(x: point.x - image.size.width / 2, y: point.y - image.size.height / 2,
                              width: image.size.width, height: image.size.height))
    }

    private static func symbolImage(_ name: String, pointSize: CGFloat, color: PlatformColor) -> PlatformImage? {
        PlatformGraphics.symbolImage(name, pointSize: pointSize, color: color)
    }
}

// MARK: - Standalone marker primitives

/// Two markers that aren't built from a `MarkerStyle` but are markers all the
/// same, and so belong here rather than in whichever package happened to need
/// them first.
///
/// Both were previously drawn inline elsewhere — the route dot in
/// TravelMapKit's thumbnail service, the numbered bullet in TravelBookKit's
/// export renderer. Keeping every glyph the app draws in one file is the point
/// of this package: it is what lets a static export match the live map, and
/// it's how a change to marker drawing reaches every surface at once.
public extension MarkerRenderer {

    /// A filled dot with a contrasting ring — the endpoints of a route on a
    /// thumbnail, and the individual points of a short track.
    ///
    /// Not `MarkerStyle.dot`: that sizes its ring as a *fraction* of the dot, so
    /// a 3pt thumbnail dot would get a hairline ring and vanish against a busy
    /// map. Here the ring is an absolute width, which is what keeps a small dot
    /// legible.
    static func drawDot(at point: CGPoint,
                        radius: CGFloat,
                        fill: Color,
                        ring: Color = .white,
                        ringWidth: CGFloat = 1.5,
                        in ctx: CGContext) {
        let outer = radius + ringWidth
        ctx.saveGState()
        ctx.setFillColor(PlatformColor(ring).cgColor)
        ctx.fillEllipse(in: CGRect(x: point.x - outer, y: point.y - outer,
                                   width: outer * 2, height: outer * 2))
        ctx.setFillColor(PlatformColor(fill).cgColor)
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                   width: radius * 2, height: radius * 2))
        ctx.restoreGState()
    }

    /// A numbered disc sized to `rect` — the badge an exported waypoints table
    /// puts before each name, matching the numbers on the map beside it.
    ///
    /// The font is derived from the rect rather than fixed, so the badge stays
    /// legible if a recipe ever asks for a bigger one.
    static func drawNumberedBullet(_ number: Int,
                                   in rect: CGRect,
                                   fill: Color,
                                   textColor: Color = .white,
                                   in ctx: CGContext) {
        PlatformGraphics.withContext(ctx) {
            ctx.saveGState()
            ctx.setFillColor(PlatformColor(fill).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.restoreGState()

            let font = PlatformFont.boldSystemFont(ofSize: max(6, rect.height * 0.56))
            let text = "\(number)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: PlatformColor(textColor)
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: rect.midX - size.width / 2,
                                  y: rect.midY - size.height / 2),
                      withAttributes: attributes)
        }
    }
}
