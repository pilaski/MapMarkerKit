import SwiftUI
import MapMarkerKit

/// Modifies one of the kit's customizable base shapes (pin or balloon) by adjusting the
/// dimension parameters it advertises, then stores the result as a named custom shape in
/// the shared `CustomShapeStore` so the Editor can build markers on top of it.
struct ShapeModifierView: View {
    @EnvironmentObject private var store: CustomShapeStore

    /// Only shapes that expose adjustable dimensions can be turned into custom shapes.
    private let bases = MarkerShape.allCases.filter(\.isCustomizable)

    @State private var base: MarkerShape = .teardrop
    @State private var customization = ShapeCustomization()
    @State private var name = ""
    @State private var fill: Color = .indigo

    private var previewStyle: MarkerStyle {
        MarkerStyle(shape: base,
                    symbol: base.showsGlyph ? .star : .none,
                    fillColor: fill,
                    size: 32,
                    customization: customization)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        LinearGradient(colors: [.green.opacity(0.5), .teal.opacity(0.55)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        MarkerView(style: previewStyle)
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                Section("Base shape") {
                    Picker("Shape", selection: $base) {
                        ForEach(bases) { Text($0.displayName).tag($0) }
                    }
                    .onChange(of: base) { _, _ in customization = ShapeCustomization() }
                    ColorPicker("Fill color", selection: $fill, supportsOpacity: true)
                }

                Section("Dimensions") {
                    ForEach(base.customizableParameters) { param in
                        parameterSlider(param)
                    }
                    Button("Reset to defaults") { customization = ShapeCustomization() }
                        .disabled(customization.isEmpty)
                }

                Section("Save") {
                    TextField("Custom shape name", text: $name)
                    Button("Save as custom shape") { save() }
                        .disabled(trimmedName.isEmpty)
                }

                if !store.shapes.isEmpty {
                    Section("Saved custom shapes") {
                        ForEach(store.shapes) { shape in
                            HStack(spacing: 16) {
                                MarkerView(style: shape.apply(to: MarkerStyle(shape: shape.base,
                                                                              symbol: shape.base.showsGlyph ? .star : .none,
                                                                              fillColor: .indigo, size: 26)))
                                    .frame(width: 44, height: 52)
                                VStack(alignment: .leading) {
                                    Text(shape.name).font(.headline)
                                    Text("Based on \(shape.base.displayName)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    base = shape.base
                                    customization = shape.customization
                                    name = shape.name
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete { store.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Shape Modifier")
        }
    }

    private func parameterSlider(_ param: ShapeParameter) -> some View {
        let binding = Binding<Double>(
            get: { Double(customization[param.id] ?? param.defaultValue) },
            set: { customization[param.id] = CGFloat($0) }
        )
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(param.name)
                Spacer()
                Text(binding.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: binding,
                   in: Double(param.range.lowerBound)...Double(param.range.upperBound))
        }
    }

    private func save() {
        store.add(CustomMarkerShape(name: trimmedName, base: base, customization: customization))
        name = ""
    }
}
