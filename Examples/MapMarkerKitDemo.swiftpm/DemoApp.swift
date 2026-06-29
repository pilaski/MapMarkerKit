import SwiftUI

/// The example app entry point. Three tabs showcase MapMarkerKit:
/// the style **Catalog**, an interactive **Editor**, and a live **Map**.
@main
struct MapMarkerKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CatalogView()
                    .tabItem { Label("Catalog", systemImage: "square.grid.2x2") }
                EditorView()
                    .tabItem { Label("Editor", systemImage: "slider.horizontal.3") }
                MapDemoView()
                    .tabItem { Label("Map", systemImage: "map") }
            }
        }
    }
}
