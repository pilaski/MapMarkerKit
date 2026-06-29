import SwiftUI
import MapMarkerKit

/// Browses `MarkerCatalog`: every predefined marker style with a live preview and
/// the list of properties it lets a user change, and every label style with its
/// preview and summary.
struct CatalogView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Marker styles") {
                    ForEach(MarkerCatalog.markerStyles) { template in
                        HStack(spacing: 16) {
                            template.preview()
                                .frame(width: 54, height: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name).font(.headline)
                                Text("Editable: " + template.capabilities.descriptions.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: template.previewSymbol)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("Shapes are predefined. Pick a style, then customise the properties it advertises.")
                }

                Section("Label styles") {
                    ForEach(MarkerCatalog.labelStyles) { template in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(template.name).font(.headline)
                                Spacer()
                                template.preview(template.name)
                                    .padding(8)
                                    .background(previewBackground, in: RoundedRectangle(cornerRadius: 8))
                            }
                            Text(template.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Catalog")
        }
    }

    /// A muted "map terrain" backdrop so light and outlined labels stay legible.
    private var previewBackground: LinearGradient {
        LinearGradient(colors: [.green.opacity(0.45), .teal.opacity(0.5)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
