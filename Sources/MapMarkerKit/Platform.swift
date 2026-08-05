#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import CoreGraphics
import CoreText

/// The handful of UIKit types the renderer actually needs, aliased to their
/// AppKit twins so the drawing code reads the same on both platforms.
///
/// These are deliberately **internal**. Internal names don't collide across
/// modules, so every package can carry its own `PlatformColor` without the app
/// ever seeing an ambiguous `PlatformColor` from two imports at once. Nothing
/// in MapMarkerKit's public API exposes one — `MarkerRenderer` takes a
/// `CGContext` and SwiftUI `Color`s, both of which are already portable.
#if canImport(UIKit)
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
typealias PlatformImage = NSImage
#endif

enum PlatformGraphics {

    /// Runs `body` with `ctx` installed as the *current* context for the
    /// platform's string- and image-drawing APIs.
    ///
    /// This is the one thing that genuinely cannot be papered over with a
    /// typealias. `NSString.draw(at:withAttributes:)` and `NSImage.draw(in:)`
    /// don't take a context — they render into an ambient one. On iOS that
    /// ambient context is whatever `UIGraphicsPushContext` last set (and
    /// `UIGraphicsImageRenderer` sets it for you, which is why the old code
    /// could ignore this). AppKit has its own stack, `NSGraphicsContext`, and
    /// it is *empty* when you hand Core Graphics a bare `CGContext` — text
    /// simply doesn't appear.
    ///
    /// `flipped: true` matters just as much: AppKit's default is a bottom-left
    /// origin, so without it every string draws mirrored about its baseline.
    /// Declaring the context flipped tells AppKit the caller is using UIKit's
    /// top-left convention, which is what all the geometry here assumes.
    static func withContext(_ ctx: CGContext, _ body: () -> Void) {
        #if canImport(UIKit)
        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }
        body()
        #elseif canImport(AppKit)
        let saved = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        defer { NSGraphicsContext.current = saved }
        body()
        #else
        body()
        #endif
    }

    /// An SF Symbol rendered in `color` at `pointSize`, as a bitmap ready to
    /// draw.
    ///
    /// UIKit tints a symbol with `withTintColor(_:renderingMode:)`; AppKit has
    /// no such call, so the macOS path draws the (template) symbol through a
    /// `.sourceIn` blend, which replaces its coverage with solid colour —
    /// the same result by a longer road.
    static func symbolImage(_ name: String, pointSize: CGFloat, color: PlatformColor) -> PlatformImage? {
        #if canImport(UIKit)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        #elseif canImport(AppKit)
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        let size = symbol.size
        guard size.width > 0, size.height > 0 else { return nil }
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        defer { tinted.unlockFocus() }
        symbol.draw(in: CGRect(origin: .zero, size: size))
        color.set()
        CGRect(origin: .zero, size: size).fill(using: .sourceIn)
        return tinted
        #else
        return nil
        #endif
    }
}
