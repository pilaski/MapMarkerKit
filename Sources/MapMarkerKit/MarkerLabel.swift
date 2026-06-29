import SwiftUI

/// Text drawn with a slim surrounding outline (a second colour around the fill), like
/// a map caption. Implemented by stamping the text in the outline colour at eight
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

    private var offsets: [CGSize] {
        let w = max(0.5, width)
        return [
            CGSize(width: -w, height: 0), CGSize(width: w, height: 0),
            CGSize(width: 0, height: -w), CGSize(width: 0, height: w),
            CGSize(width: -w, height: -w), CGSize(width: w, height: -w),
            CGSize(width: -w, height: w), CGSize(width: w, height: w)
        ]
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

/// A standalone marker label honouring a `LabelStyle`: a plain or outlined string,
/// optionally split into two coloured segments, with a pill / rectangular / no
/// background. Content is supplied as `primary` (and optional `secondary`) strings.
public struct MarkerLabel: View {
    let style: LabelStyle
    let primary: String?
    let secondary: String?

    public init(style: LabelStyle, primary: String?, secondary: String? = nil) {
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

    @ViewBuilder
    private func segment(_ text: String, background: Color) -> some View {
        textView(text)
            .padding(.horizontal, style.shape == .none ? 0 : 5)
            .padding(.vertical, style.shape == .none ? 0 : 1.5)
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
