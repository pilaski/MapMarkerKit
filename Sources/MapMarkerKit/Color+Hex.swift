import SwiftUI

extension Color {
    /// An 8-digit RGBA hex string (e.g. "3478F6FF") for persisting a colour. Dynamic
    /// colours (e.g. `.primary`) are resolved to a concrete value so they persist as
    /// real components.
    public var rgbaHex: String {
        #if canImport(UIKit)
        let uiColor = UIColor(self).resolvedColor(with: .current)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if !uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            var w: CGFloat = 1
            if uiColor.getWhite(&w, alpha: &a) { r = w; g = w; b = w }
        }
        func component(_ value: CGFloat) -> String {
            String(format: "%02X", Int((max(0, min(1, value)) * 255).rounded()))
        }
        return component(r) + component(g) + component(b) + component(a)
        #else
        return "0000FFFF"
        #endif
    }

    /// Reconstructs a colour from an 8-digit RGBA hex string.
    public init?(rgbaHex: String) {
        let string = rgbaHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard string.count == 8, let value = UInt32(string, radix: 16) else { return nil }
        self = Color(.sRGB,
                     red: Double((value >> 24) & 0xFF) / 255,
                     green: Double((value >> 16) & 0xFF) / 255,
                     blue: Double((value >> 8) & 0xFF) / 255,
                     opacity: Double(value & 0xFF) / 255)
    }
}
