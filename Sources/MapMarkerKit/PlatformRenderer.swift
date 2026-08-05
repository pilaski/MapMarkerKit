#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import CoreGraphics
import Foundation

/// Portable replacements for `UIGraphicsImageRenderer` and
/// `UIGraphicsPDFRenderer`, which are the last genuinely iOS-only pieces of the
/// map/export rendering stack.
///
/// Both deal in **`CGContext` and `CGImage`** rather than `UIImage`/`NSImage`
/// on purpose. Those two are portable types that need no aliasing, so this can
/// live in MapMarkerKit — which every rendering package already depends on —
/// without exporting a `PlatformImage` name that would then collide with
/// TravelDataStore's at an app-side call site. Callers wrap the `CGImage` in
/// whatever image type they actually want, which is one line each.
///
/// The iOS paths still go through UIKit. They could have been unified on Core
/// Graphics, but the app ships today and its rendering is known-good; keeping
/// the UIKit implementations means macOS gains a path without iOS changing
/// behaviour at all.
///
/// **Coordinates.** Both renderers hand the drawing block a context whose
/// origin is **top-left, y down** — UIKit's convention, which all the existing
/// drawing code assumes. On iOS that's what UIKit already provides; on macOS
/// this flips the CTM to match. The platform's ambient graphics context is
/// installed too, so `NSString.draw(at:)` and image drawing work inside the
/// block on both platforms.
public enum PlatformRenderer {

    // MARK: - Bitmap

    /// Renders `draw` into a bitmap `size` points across at `scale` pixels per
    /// point, returning the result. Nil only if the backing context could not
    /// be created (an implausible size, or out of memory).
    public static func image(size: CGSize,
                             scale: CGFloat,
                             opaque: Bool = false,
                             _ draw: (CGContext) -> Void) -> CGImage? {
        guard size.width > 0, size.height > 0, scale > 0 else { return nil }

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = opaque
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(ctx.cgContext)
        }
        return image.cgImage

        #elseif canImport(AppKit)
        let pixelsWide = Int((size.width * scale).rounded())
        let pixelsHigh = Int((size.height * scale).rounded())
        guard pixelsWide > 0, pixelsHigh > 0,
              let ctx = CGContext(
                data: nil,
                width: pixelsWide,
                height: pixelsHigh,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)
        else { return nil }

        if opaque {
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
        }
        // Flip to UIKit's top-left origin: a user point (0,0) has to land on the
        // top edge, which in Core Graphics device space is y == pixelsHigh.
        ctx.translateBy(x: 0, y: CGFloat(pixelsHigh))
        ctx.scaleBy(x: scale, y: -scale)

        withAmbientContext(ctx) { draw(ctx) }
        return ctx.makeImage()

        #else
        return nil
        #endif
    }

    // MARK: - PDF

    /// Writes a PDF whose pages are `bounds` in size, returning the bytes.
    ///
    /// The block receives a `PDFPageWriter`; call `beginPage()` before drawing
    /// each page. A document with no `beginPage()` call produces an empty PDF
    /// rather than a malformed one.
    public static func pdf(bounds: CGRect, _ draw: (PDFPageWriter) -> Void) -> Data {
        #if canImport(UIKit)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
            draw(PDFPageWriter(uiContext: ctx, bounds: bounds))
        }

        #elseif canImport(AppKit)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return Data() }
        var mediaBox = bounds
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        let writer = PDFPageWriter(cgContext: ctx, bounds: bounds)
        draw(writer)
        writer.endOpenPage()
        ctx.closePDF()
        return data as Data

        #else
        return Data()
        #endif
    }

    // MARK: - Ambient context

    /// Installs `ctx` as the platform's current graphics context for the length
    /// of `body` — see `PlatformGraphics.withContext`, which this mirrors for
    /// the renderer's own use.
    static func withAmbientContext(_ ctx: CGContext, _ body: () -> Void) {
        PlatformGraphics.withContext(ctx, body)
    }
}

/// Page-by-page access to a PDF being written by `PlatformRenderer.pdf`.
public final class PDFPageWriter {
    /// The context to draw each page into. Top-left origin, y down.
    public let cgContext: CGContext

    private let bounds: CGRect
    #if canImport(UIKit)
    private let uiContext: UIGraphicsPDFRendererContext
    #endif
    private var pageOpen = false
    #if canImport(AppKit)
    /// Whatever was current before the first page, put back when the last one
    /// closes — the writer borrows the ambient context, it doesn't own it.
    private var savedContext: NSGraphicsContext?
    #endif

    #if canImport(UIKit)
    init(uiContext: UIGraphicsPDFRendererContext, bounds: CGRect) {
        self.uiContext = uiContext
        self.cgContext = uiContext.cgContext
        self.bounds = bounds
    }
    #elseif canImport(AppKit)
    init(cgContext: CGContext, bounds: CGRect) {
        self.cgContext = cgContext
        self.bounds = bounds
    }
    #endif

    /// Starts a new page, closing the previous one.
    public func beginPage() {
        #if canImport(UIKit)
        uiContext.beginPage()
        #elseif canImport(AppKit)
        if !pageOpen { savedContext = NSGraphicsContext.current }
        endOpenPage(restoringContext: false)
        var box = bounds
        cgContext.beginPage(mediaBox: &box)
        // Same top-left flip as the bitmap renderer; the CTM resets per page,
        // so this has to be re-applied each time rather than set up once.
        cgContext.translateBy(x: 0, y: bounds.height)
        cgContext.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: true)
        pageOpen = true
        #endif
    }

    /// Closes the page currently being drawn, if any. A no-op on iOS, where
    /// `UIGraphicsPDFRenderer` ends pages itself.
    func endOpenPage(restoringContext: Bool = true) {
        #if canImport(AppKit)
        guard pageOpen else { return }
        cgContext.endPage()
        pageOpen = false
        if restoringContext {
            NSGraphicsContext.current = savedContext
            savedContext = nil
        }
        #endif
    }
}
