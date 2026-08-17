import Foundation
import CoreGraphics
import SwiftUI

/// Markers as **SVG** — the third rendering engine, beside `MarkerView` for the
/// screen and `MarkerRenderer` for bitmaps and PDFs.
///
/// It exists because one output can't be served by either of the others. An
/// outline map exported as vector has to stay sharp at whatever size a print
/// service asks for, and neither a SwiftUI view nor a `CGContext` produces
/// something that scales — a screenshot of a marker is pixels, and pixels are
/// what vector output exists to avoid.
///
/// Three engines rather than one is the honest shape of the problem: each has a
/// different notion of what "draw" means, and a common abstraction over
/// `Path`, `CGContext` and a string of markup would be a fourth thing to keep
/// in step rather than a saving. What *is* shared — and what makes the three
/// agree — is `MarkerGeometry`: every engine asks it where the shape sits and
/// how big it is, so only the ink differs.
///
/// Emits a fragment, not a document: a `<g>` the caller places inside its own
/// `<svg>`. That keeps this ignorant of the page it lands on.
///
/// **Shapes only — no glyph and no label.** Text in SVG needs a font the
/// consumer has, and the shapes this was built for (`MarkerShape.pointMarkers`)
/// carry neither. A caller that wants a lettered marker in vector should draw
/// the shape here and add its own `<text>`, where it knows what fonts the
/// document embeds.
public enum MarkerSVGRenderer {

    /// The marker at `point`, as an SVG fragment.
    ///
    /// `point` is the coordinate the marker marks — its **base point**, which
    /// for a pin is the tip and for every centred shape is the middle. Same
    /// contract as `MarkerRenderer.drawMarker`, so a caller that has placed one
    /// has placed the other.
    public static func svg(for style: MarkerStyle, at point: CGPoint,
                           highlighted: Bool = false) -> String {
        let geometry = MarkerGeometry.make(for: style, highlighted: highlighted)
        // The geometry is expressed in a box whose origin is top-left; the
        // caller gives us where the base point goes, so shift by the difference.
        let origin = CGPoint(x: point.x - geometry.basePoint.x,
                             y: point.y - geometry.basePoint.y)
        let box = geometry.baseBox.offsetBy(dx: origin.x, dy: origin.y)
        let fill = SVGPaint(style.fillColor)
        let stroke = SVGPaint(style.strokeColor)

        var body: String
        switch style.shape {
        case .dot, .circle:
            body = circle(box, fill: fill, stroke: stroke,
                          strokeWidth: box.width * (style.shape == .dot ? 0.16 : 0.18))
        case .ring:
            let width = box.width * 0.2
            body = ellipse(box.insetBy(dx: width / 2, dy: width / 2),
                           fill: nil, stroke: fill, strokeWidth: width)
        case .ringedDot:
            let width = box.width * 0.18
            body = ellipse(box.insetBy(dx: width / 2, dy: width / 2),
                           fill: nil, stroke: stroke, strokeWidth: width)
            body += ellipse(centred(on: centre(of: box), side: box.width * 0.52),
                            fill: fill, stroke: nil, strokeWidth: 0)
        case .crosshair:
            let mid = centre(of: box)
            let width = box.width * 0.12
            body = line(from: CGPoint(x: box.minX, y: mid.y),
                        to: CGPoint(x: box.maxX, y: mid.y), paint: fill, width: width)
            body += line(from: CGPoint(x: mid.x, y: box.minY),
                         to: CGPoint(x: mid.x, y: box.maxY), paint: fill, width: width)
            body += ellipse(centred(on: mid, side: box.width * 0.32),
                            fill: fill, stroke: nil, strokeWidth: 0)
        case .square:
            body = rect(box, cornerRadius: 3, fill: fill, stroke: stroke,
                        strokeWidth: max(1, box.width * 0.1))
        case .diamond:
            let mid = centre(of: box)
            let points = [CGPoint(x: mid.x, y: box.minY), CGPoint(x: box.maxX, y: mid.y),
                          CGPoint(x: mid.x, y: box.maxY), CGPoint(x: box.minX, y: mid.y)]
            body = polygon(points, fill: fill, stroke: stroke,
                           strokeWidth: max(1, box.width * 0.1))
        case .teardrop, .balloon:
            body = pin(geometry, origin: origin, fill: fill, stroke: stroke,
                       balloon: style.shape == .balloon)
        }
        return "<g>\(body)</g>"
    }

    // MARK: Shapes

    private static func centre(of box: CGRect) -> CGPoint {
        CGPoint(x: box.midX, y: box.midY)
    }

    private static func centred(on point: CGPoint, side: CGFloat) -> CGRect {
        CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
    }

    private static func circle(_ box: CGRect, fill: SVGPaint?, stroke: SVGPaint?,
                               strokeWidth: CGFloat) -> String {
        ellipse(box, fill: fill, stroke: stroke, strokeWidth: strokeWidth)
    }

    private static func ellipse(_ box: CGRect, fill: SVGPaint?, stroke: SVGPaint?,
                                strokeWidth: CGFloat) -> String {
        "<circle cx=\"\(number(box.midX))\" cy=\"\(number(box.midY))\" "
            + "r=\"\(number(box.width / 2))\"\(paint(fill: fill, stroke: stroke, width: strokeWidth))/>"
    }

    private static func rect(_ box: CGRect, cornerRadius: CGFloat,
                             fill: SVGPaint?, stroke: SVGPaint?, strokeWidth: CGFloat) -> String {
        "<rect x=\"\(number(box.minX))\" y=\"\(number(box.minY))\" "
            + "width=\"\(number(box.width))\" height=\"\(number(box.height))\" "
            + "rx=\"\(number(cornerRadius))\"\(paint(fill: fill, stroke: stroke, width: strokeWidth))/>"
    }

    private static func polygon(_ points: [CGPoint], fill: SVGPaint?, stroke: SVGPaint?,
                                strokeWidth: CGFloat) -> String {
        let list = points.map { "\(number($0.x)),\(number($0.y))" }.joined(separator: " ")
        return "<polygon points=\"\(list)\"\(paint(fill: fill, stroke: stroke, width: strokeWidth))/>"
    }

    private static func line(from start: CGPoint, to end: CGPoint,
                             paint: SVGPaint, width: CGFloat) -> String {
        "<line x1=\"\(number(start.x))\" y1=\"\(number(start.y))\" "
            + "x2=\"\(number(end.x))\" y2=\"\(number(end.y))\" "
            + "stroke=\"\(paint.color)\"\(paint.opacityAttribute(name: "stroke-opacity")) "
            + "stroke-width=\"\(number(width))\" stroke-linecap=\"butt\"/>"
    }

    /// A teardrop or balloon as a path: a round head over a tip that lands on
    /// the coordinate. Approximated with two quadratic curves, which is what
    /// the on-screen shape is too.
    private static func pin(_ geometry: MarkerGeometry, origin: CGPoint,
                            fill: SVGPaint, stroke: SVGPaint, balloon: Bool) -> String {
        let head = geometry.secondaryBox.offsetBy(dx: origin.x, dy: origin.y)
        let tip = CGPoint(x: geometry.basePoint.x + origin.x,
                          y: geometry.basePoint.y + origin.y)
        let headCentre = CGPoint(x: head.midX, y: head.midY)
        let radius = head.width / 2
        let path = "M \(number(tip.x)) \(number(tip.y)) "
            + "Q \(number(headCentre.x - radius)) \(number(headCentre.y + radius * 0.6)) "
            + "\(number(headCentre.x - radius)) \(number(headCentre.y)) "
            + "A \(number(radius)) \(number(radius)) 0 1 1 "
            + "\(number(headCentre.x + radius)) \(number(headCentre.y)) "
            + "Q \(number(headCentre.x + radius)) \(number(headCentre.y + radius * 0.6)) "
            + "\(number(tip.x)) \(number(tip.y)) Z"
        var out = "<path d=\"\(path)\""
            + paint(fill: fill, stroke: stroke, width: max(1, head.width * 0.05)) + "/>"
        if balloon {
            out += ellipse(centred(on: headCentre, side: head.width * 0.34),
                           fill: stroke, stroke: nil, strokeWidth: 0)
        }
        return out
    }

    // MARK: Attributes

    private static func paint(fill: SVGPaint?, stroke: SVGPaint?, width: CGFloat) -> String {
        var out = ""
        if let fill {
            out += " fill=\"\(fill.color)\"" + fill.opacityAttribute(name: "fill-opacity")
        } else {
            out += " fill=\"none\""
        }
        if let stroke, width > 0 {
            out += " stroke=\"\(stroke.color)\"" + stroke.opacityAttribute(name: "stroke-opacity")
            out += " stroke-width=\"\(number(width))\""
        }
        return out
    }

    private static func number(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }
}

/// A SwiftUI `Color` split into what SVG wants: an opaque `#RRGGBB` and a
/// separate opacity.
///
/// SVG has no eight-digit hex — `fill="#RRGGBBAA"` is silently wrong in some
/// renderers and an error in others — so the alpha has to travel as its own
/// attribute. Splitting it here means no shape function has to remember that.
struct SVGPaint {
    let color: String
    let opacity: Double

    init(_ color: Color) {
        let rgba = color.rgbaHex
        if rgba.count == 8 {
            self.color = "#" + rgba.prefix(6)
            self.opacity = Double(UInt8(rgba.suffix(2), radix: 16) ?? 255) / 255
        } else {
            self.color = "#" + rgba
            self.opacity = 1
        }
    }

    /// Emitted only when it isn't 1 — an opacity of 1 on every element is noise
    /// in a file someone may well open in an editor.
    func opacityAttribute(name: String) -> String {
        opacity >= 0.999 ? "" : " \(name)=\"\(String(format: "%.3f", opacity))\""
    }
}
