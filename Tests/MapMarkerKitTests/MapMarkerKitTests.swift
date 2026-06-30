import XCTest
import SwiftUI
@testable import MapMarkerKit

final class MapMarkerKitTests: XCTestCase {

    func testCatalogListsEveryShape() {
        let shapes = Set(MarkerCatalog.markerStyles.map(\.shape))
        XCTAssertEqual(shapes, Set(MarkerShape.allCases))
    }

    func testCatalogLookupById() {
        XCTAssertNotNil(MarkerCatalog.markerStyle(id: "pin"))
        XCTAssertEqual(MarkerCatalog.markerStyle(id: "pin")?.shape, .teardrop)
        XCTAssertNotNil(MarkerCatalog.labelStyle(id: "outlined"))
        XCTAssertNil(MarkerCatalog.markerStyle(id: "missing"))
    }

    func testCapabilitiesDescribeEditableProperties() {
        let circle = MarkerCatalog.markerStyle(id: "circle")!
        XCTAssertTrue(circle.capabilities.contains(.fillColor))
        XCTAssertTrue(circle.capabilities.contains(.symbol))
        XCTAssertTrue(circle.capabilities.descriptions.contains("Marker color"))
    }

    func testDotStyleHasNoSymbolCapability() {
        let dot = MarkerCatalog.markerStyle(id: "dot")!
        XCTAssertFalse(dot.capabilities.contains(.symbol))
        XCTAssertFalse(dot.shape.showsGlyph)
    }

    func testMarkerSymbolRawValueRoundTrips() {
        for symbol in MarkerSymbol.pickable {
            XCTAssertEqual(MarkerSymbol(rawValue: symbol.rawValue), symbol)
        }
        XCTAssertEqual(MarkerSymbol(rawValue: "bolt.fill"), .custom("bolt.fill"))
        XCTAssertEqual(MarkerSymbol.custom("bolt.fill").rawValue, "bolt.fill")
    }

    func testBottomAnchoredShapes() {
        XCTAssertTrue(MarkerShape.teardrop.isBottomAnchored)
        XCTAssertTrue(MarkerShape.balloon.isBottomAnchored)
        XCTAssertFalse(MarkerShape.circle.isBottomAnchored)
        XCTAssertFalse(MarkerShape.dot.isBottomAnchored)
    }

    func testGeometryBasePointForCircleIsCentre() {
        let style = MarkerStyle(shape: .circle, size: 20)
        let geo = MarkerGeometry.make(for: style)
        XCTAssertEqual(geo.basePoint, CGPoint(x: 10, y: 10))
        XCTAssertEqual(geo.secondaryPoint, geo.basePoint)
    }

    func testGeometryBasePointForPinIsTip() {
        let style = MarkerStyle(shape: .teardrop, size: 28)
        let geo = MarkerGeometry.make(for: style)
        XCTAssertEqual(geo.basePoint.x, geo.size.width / 2, accuracy: 0.001)
        XCTAssertEqual(geo.basePoint.y, geo.size.height, accuracy: 0.001)
        // The secondary point (head) sits above the tip.
        XCTAssertLessThan(geo.secondaryPoint.y, geo.basePoint.y)
    }

    func testSecondaryAnchorBoxDiffersForPin() {
        let style = MarkerStyle(shape: .teardrop, size: 28)
        let geo = MarkerGeometry.make(for: style)
        XCTAssertNotEqual(geo.box(for: .base), geo.box(for: .secondary))
    }

    func testBalloonGeometryScalesWithSize() {
        let small = MarkerGeometry.make(for: MarkerStyle(shape: .balloon, size: 26))
        let large = MarkerGeometry.make(for: MarkerStyle(shape: .balloon, size: 52))
        // The body width tracks the style size, and the pointer scales with it.
        XCTAssertEqual(small.size.width, 26, accuracy: 0.001)
        XCTAssertEqual(large.size.width, 52, accuracy: 0.001)
        XCTAssertEqual(large.size.height, small.size.height * 2, accuracy: 0.001)
        XCTAssertEqual(large.glyphCenter.x, small.glyphCenter.x * 2, accuracy: 0.001)
    }

    func testBalloonStyleHasSizeCapability() {
        let balloon = MarkerCatalog.markerStyle(id: "balloon")!
        XCTAssertTrue(balloon.capabilities.contains(.size))
    }

    func testCustomizableShapesAdvertiseParameters() {
        XCTAssertTrue(MarkerShape.teardrop.isCustomizable)
        XCTAssertTrue(MarkerShape.balloon.isCustomizable)
        XCTAssertFalse(MarkerShape.circle.isCustomizable)
        XCTAssertFalse(MarkerShape.dot.isCustomizable)
        XCTAssertEqual(MarkerShape.balloon.customizableParameters.map(\.id), ["pointer", "corner"])
    }

    func testCustomizationResolvesDefaultAndClamps() {
        let shape = MarkerShape.balloon
        // Unset -> default.
        XCTAssertEqual(shape.value(of: "pointer", in: ShapeCustomization()),
                       BalloonShape.pointerRatio, accuracy: 0.0001)
        // Out-of-range overrides clamp to the parameter's bounds.
        XCTAssertEqual(shape.value(of: "pointer", in: ShapeCustomization(values: ["pointer": 99])),
                       0.60, accuracy: 0.0001)
        XCTAssertEqual(shape.value(of: "pointer", in: ShapeCustomization(values: ["pointer": -5])),
                       0.15, accuracy: 0.0001)
    }

    func testBalloonGeometryRespectsPointerCustomization() {
        let base = MarkerStyle(shape: .balloon, size: 26)
        let longer = MarkerStyle(shape: .balloon, size: 26,
                                 customization: ShapeCustomization(values: ["pointer": 0.6]))
        let baseGeo = MarkerGeometry.make(for: base)
        let longerGeo = MarkerGeometry.make(for: longer)
        // A longer pointer makes the full box taller while the body width is unchanged.
        XCTAssertEqual(baseGeo.size.width, longerGeo.size.width, accuracy: 0.001)
        XCTAssertGreaterThan(longerGeo.size.height, baseGeo.size.height)
        XCTAssertEqual(longerGeo.size.height, 26 + 26 * 0.6, accuracy: 0.001)
    }

    func testTeardropGeometryRespectsAspectCustomization() {
        let style = MarkerStyle(shape: .teardrop, size: 28,
                                customization: ShapeCustomization(values: ["aspect": 1.6]))
        let geo = MarkerGeometry.make(for: style)
        XCTAssertEqual(geo.size.height, 28 * 1.6, accuracy: 0.001)
    }

    func testCustomShapeStoreAddReplaceRemove() {
        let store = CustomShapeStore()
        let shape = CustomMarkerShape(name: "Tall pin", base: .teardrop,
                                      customization: ShapeCustomization(values: ["aspect": 1.7]))
        store.add(shape)
        XCTAssertEqual(store.shapes.count, 1)
        // Re-adding the same id replaces rather than appends.
        var renamed = shape
        renamed.name = "Taller pin"
        store.add(renamed)
        XCTAssertEqual(store.shapes.count, 1)
        XCTAssertEqual(store.shapes.first?.name, "Taller pin")
        store.remove(shape)
        XCTAssertTrue(store.shapes.isEmpty)
    }

    func testCustomShapeAppliesBaseAndCustomization() {
        let custom = CustomMarkerShape(name: "Round balloon", base: .balloon,
                                       customization: ShapeCustomization(values: ["corner": 0.5]))
        let applied = custom.apply(to: MarkerStyle(shape: .circle, fillColor: .red, size: 30))
        XCTAssertEqual(applied.shape, .balloon)
        XCTAssertEqual(applied.customization.values["corner"], 0.5)
        // Untouched properties carry over.
        XCTAssertEqual(applied.size, 30)
    }

    func testColorHexRoundTrip() {
        XCTAssertNotNil(Color(rgbaHex: "3478F6FF"))
        XCTAssertNil(Color(rgbaHex: "xyz"))
    }

    func testCaptionLabelIsOutlinedWithoutBackground() {
        XCTAssertEqual(MarkerLabelStyle.caption.textStyle, .outlined)
        XCTAssertEqual(MarkerLabelStyle.caption.shape, .none)
    }
}
