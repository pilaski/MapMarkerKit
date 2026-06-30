import SwiftUI
import MapMarkerKit

/// The example app entry point. Four tabs showcase MapMarkerKit: the style **Catalog**,
/// an interactive **Editor**, a **Shapes** modifier that saves custom shapes, and a live
/// **Map**. The custom-shape store is shared so shapes saved in the modifier appear in
/// the editor's shape picker.
@main
struct MapMarkerKitDemoApp: App {
    @StateObject private var shapeStore = CustomShapeStore(shapes: [
        // A seeded example so the flow is visible immediately; users add their own in
        // the Shapes tab.
        CustomMarkerShape(name: "Tall pin", base: .teardrop,
                          customization: ShapeCustomization(values: ["aspect": 1.7, "sharpness": 0.9])),
        CustomMarkerShape(name: "Long balloon", base: .balloon,
                          customization: ShapeCustomization(values: ["pointer": 0.55, "corner": 0.2]))
    ])

    var body: some Scene {
        WindowGroup {
            TabView {
                CatalogView()
                    .tabItem { Label("Catalog", systemImage: "square.grid.2x2") }
                EditorView()
                    .tabItem { Label("Editor", systemImage: "slider.horizontal.3") }
                ShapeModifierView()
                    .tabItem { Label("Shapes", systemImage: "pencil.and.outline") }
                MapDemoView()
                    .tabItem { Label("Map", systemImage: "map") }
            }
            .environmentObject(shapeStore)
        }
    }
}
