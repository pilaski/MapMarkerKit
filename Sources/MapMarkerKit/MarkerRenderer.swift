#if canImport(UIKit)
import SwiftUI
import UIKit
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
        let geo = MarkerGeometry.make(for: style, highlighted: highlighted)
        // Translate so the geometry's base point lands on `point`.
        let origin = CGPoint(x: point.x - geo.basePoint.x, y: point.y - geo.basePoint.y)
        let fill = highlighted ? UIColor.red : UIColor(style.fillColor)
        let stroke = UIColor(style.strokeColor)
        let glyphColor = UIColor(style.glyphColor)

        switch style.shape {
        case .circle:
            drawCircle(in: geo.baseBox.offsetBy(dx: origin.x, dy: origin.y),
                       fill: fill, stroke: stroke, borderRatio: 0.18, in: ctx)
            drawGlyph(style.symbol, at: shift(geo.glyphCenter, by: origin),
                      pointSize: geo.glyphPointSize, color: glyphColor, number: number, in: ctx)
        case .dot:
            drawCircle(in: geo.baseBox.offsetBy(dx: origin.x, dy: origin.y),
                       fill: fill, stroke: stroke, borderRatio: 0.16, in: ctx)
        case .teardrop:
            let rect = CGRect(origin: origin, size: geo.size)
            let path = TeardropPinShape().path(in: rect)
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
            let path = BalloonShape().path(in: rect)
            fillAndStroke(path, fill: fill, stroke: stroke, lineWidth: 1.5, in: ctx)
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

    private static func labelFont(_ style: MarkerLabelStyle) -> UIFont {
        UIFont.systemFont(ofSize: max(8, style.fontSize), weight: .semibold)
    }

    private static func drawLabel(_ style: MarkerLabelStyle, parts: [String],
                                  around refBox: CGRect, in ctx: CGContext) {
        let font = labelFont(style)
        let hasBackground = style.shape != .none
        let pad = hasBackground ? labelPad : 0

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

        let textColor = UIColor(style.textColor)
        let backgrounds = style.twoSegment && parts.count == 2
            ? [UIColor(style.backgroundColor), UIColor(style.secondaryColor)]
            : [UIColor(style.backgroundColor)]

        var x = origin.x
        for (i, part) in parts.enumerated() {
            let textSize = (part as NSString).size(withAttributes: [.font: font])
            let box = CGRect(x: x, y: origin.y, width: textSize.width + pad * 2, height: textSize.height + pad * 2)
            if hasBackground {
                let bg = backgrounds[min(i, backgrounds.count - 1)]
                let radius: CGFloat = style.shape == .pill ? box.height / 2 : 3
                ctx.saveGState()
                ctx.setFillColor(bg.cgColor)
                ctx.addPath(UIBezierPath(roundedRect: box, cornerRadius: radius).cgPath)
                ctx.fillPath()
                ctx.restoreGState()
            }
            let textOrigin = CGPoint(x: x + pad, y: box.minY + pad)
            drawText(part, at: textOrigin, font: font, style: style, textColor: textColor, in: ctx)
            x += box.width
        }
    }

    private static func drawText(_ text: String, at point: CGPoint, font: UIFont,
                                 style: MarkerLabelStyle, textColor: UIColor, in ctx: CGContext) {
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
                .strokeColor: UIColor(style.outlineColor),
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

    private static func drawCircle(in rect: CGRect, fill: UIColor, stroke: UIColor,
                                   borderRatio: CGFloat, in ctx: CGContext) {
        let border = max(1, rect.width / 2 * borderRatio)
        ctx.saveGState()
        ctx.setFillColor(stroke.cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -border, dy: -border))
        ctx.setFillColor(fill.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()
    }

    private static func fillAndStroke(_ path: Path, fill: UIColor, stroke: UIColor,
                                      lineWidth: CGFloat, in ctx: CGContext) {
        let cg = path.cgPath
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.25).cgColor)
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(cg); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addPath(cg); ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawGlyph(_ symbol: MarkerSymbol, at point: CGPoint,
                                  pointSize: CGFloat, color: UIColor, number: Int?, in ctx: CGContext) {
        if symbol.isNumber, let number {
            let font = UIFont.systemFont(ofSize: pointSize * 1.05, weight: .bold)
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

    private static func symbolImage(_ name: String, pointSize: CGFloat, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }
}
#endif
