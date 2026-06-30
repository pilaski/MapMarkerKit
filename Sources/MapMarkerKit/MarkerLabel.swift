import SwiftUI
import CoreGraphics

/// Text drawn with a slim surrounding outline (a second colour around the fill), like
/// a map caption. Implemented by stamping the text in the outline colour at several
/// offsets behind the fill copy, which works on every supported OS without private API.
public struct OutlinedText: View {
    let text: String
    let font: Font
    let fill: Color
    let outline: Color
    let width: CGFloat

    public init(_ text: String, font: Font, fill: Color, outline: Color, width: CGFloat) {
        self.text = text
        self.font = font
        self.fill = fill
        self.outline = outline
        self.width = width
    }

    /// Offsets sampled evenly around a circle of radius `width`, so every stamp sits the
    /// same distance from the glyph (the old 8-point grid put diagonals ~1.4× further
    /// out, which showed as a star at larger widths). The sample count grows with the
    /// width so a thick outline stays a smooth ring instead of separating into dots.
    private var offsets: [CGSize] {
        let w = max(0.5, width)
        let count = max(8, Int((w * 4).rounded()))
        return (0..<count).map { i in
            let angle = (Double(i) / Double(count)) * 2 * .pi
            return CGSize(width: CGFloat(cos(angle)) * w, height: CGFloat(sin(angle)) * w)
        }
    }

    public var body: some View {
        ZStack {
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, off in
                Text(text).font(font).foregroundStyle(outline).offset(off)
            }
            Text(text).font(font).foregroundStyle(fill)
        }
    }
}

/// A standalone marker label honouring a `MarkerLabelStyle`: a plain or outlined string,
/// optionally split into two coloured segments, with a pill / rectangular / no
/// background. Content is supplied as `primary` (and optional `secondary`) strings.
public struct MarkerLabel: View {
    let style: MarkerLabelStyle
    let primary: String?
    let secondary: String?

    public init(style: MarkerLabelStyle, primary: String?, secondary: String? = nil) {
        self.style = style
        self.primary = primary
        self.secondary = secondary
    }

    /// The non-empty parts to draw (the secondary only counts in two-segment mode).
    private var parts: [String] {
        [primary, style.twoSegment ? secondary : nil]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    public var body: some View {
        if parts.isEmpty {
            EmptyView()
        } else if style.twoSegment, parts.count == 2 {
            HStack(spacing: 0) {
                segment(parts[0], background: style.backgroundColor)
                segment(parts[1], background: style.secondaryColor)
            }
            .clipShape(style.shape.clipShape)
            .shadow(radius: style.shape == .none ? 0 : 1)
        } else if let text = parts.first {
            segment(text, background: style.shape == .none ? .clear : style.backgroundColor)
                .clipShape(style.shape.clipShape)
                .shadow(radius: style.shape == .none ? 0 : 1)
        }
    }

    /// Extra background padding so an outlined glyph (which bleeds ~`outlineWidth`
    /// past its bounds) isn't clipped or cramped by the pill / rectangle edge.
    private var outlinePad: CGFloat {
        style.textStyle == .outlined ? max(0.5, style.outlineWidth) : 0
    }

    @ViewBuilder
    private func segment(_ text: String, background: Color) -> some View {
        textView(text)
            .padding(.horizontal, style.shape == .none ? 0 : 5 + outlinePad)
            .padding(.vertical, style.shape == .none ? 0 : 1.5 + outlinePad)
            .background(background)
    }

    @ViewBuilder
    private func textView(_ text: String) -> some View {
        switch style.textStyle {
        case .plain:
            Text(text)
                .font(style.font)
                .foregroundStyle(style.textColor)
        case .outlined:
            OutlinedText(text, font: style.font, fill: style.textColor,
                         outline: style.outlineColor, width: style.outlineWidth)
        }
    }
}
