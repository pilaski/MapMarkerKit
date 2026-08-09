import SwiftUI

/// The small round badge that sits on a track and says what kind of track it is
/// — a glyph in a coloured disc with a light ring, placed at the line's
/// midpoint.
///
/// It reads as a marker and is drawn like one, so it belongs here with the rest
/// of them rather than inline in whichever map view happened to need it.
///
/// The kit deliberately doesn't know what a "track kind" is — that's the app's
/// domain. Callers pass a symbol name and a colour, exactly as they do for
/// `MarkerStyle`.
///
/// There is **no Core Graphics counterpart**, unlike every other marker here.
/// This badge is a tap target: it appears only while segments are selectable,
/// and never in a snapshot, a thumbnail or an export. A renderer for it would
/// be code that nothing could ever call.
public struct TrackTypeBadge: View {
    public let systemImage: String
    public var color: Color
    /// Diameter of the glyph's font. The disc and ring scale from it, so one
    /// number changes the whole badge.
    public var glyphSize: CGFloat
    public var glyphColor: Color
    public var ringColor: Color

    public init(systemImage: String,
                color: Color,
                glyphSize: CGFloat = 11,
                glyphColor: Color = .white,
                ringColor: Color = .white) {
        self.systemImage = systemImage
        self.color = color
        self.glyphSize = glyphSize
        self.glyphColor = glyphColor
        self.ringColor = ringColor
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: glyphSize, weight: .semibold))
            .foregroundStyle(glyphColor)
            .padding(glyphSize * 0.45)
            .background(color, in: Circle())
            // The ring is what keeps the badge legible over imagery, where the
            // disc's own colour can land on something close to it.
            .overlay(Circle().strokeBorder(ringColor, lineWidth: glyphSize * 0.14))
            .shadow(radius: 1)
    }
}

#Preview("Track type badges") {
    HStack(spacing: 16) {
        TrackTypeBadge(systemImage: "figure.walk", color: .green)
        TrackTypeBadge(systemImage: "car.fill", color: .blue)
        TrackTypeBadge(systemImage: "figure.equestrian.sports", color: .brown)
        TrackTypeBadge(systemImage: "ferry.fill", color: .teal, glyphSize: 18)
    }
    .padding()
    .background(.gray)
}
