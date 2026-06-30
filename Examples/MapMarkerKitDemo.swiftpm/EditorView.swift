import SwiftUI
import MapMarkerKit

/// An interactive editor that builds a `MarkerStyle` and `MarkerLabelStyle` from controls
/// and renders the result live — the quickest way to see what the toolkit can do.
struct EditorView: View {
    @EnvironmentObject private var shapeStore: CustomShapeStore

    // Marker
    @State private var shape: MarkerShape = .teardrop
    /// The selected saved custom shape, or `nil` to use the predefined `shape` above.
    @State private var customShapeID: UUID? = nil
    @State private var symbol: MarkerSymbol = .pin
    @State private var fill: Color = .purple
    @State private var glyph: Color = .white
    @State private var stroke: Color = .white
    @State private var size: Double = 30

    // Label
    @State private var showLabel = true
    @State private var primary = "Berlin"
    @State private var secondary = "DE"
    @State private var placement: LabelPlacement = .bottom
    @State private var anchor: LabelAnchor = .base
    @State private var distance: Double = 5
    @State private var fontSize: Double = 13
    @State private var textColor: Color = .white
    @State private var textStyle: LabelTextStyle = .outlined
    @State private var outlineColor: Color = .black
    @State private var outlineWidth: Double = 1
    @State private var labelShape: LabelShape = .none
    @State private var background: Color = Color.white.opacity(0.9)
    @State private var twoSegment = false
    @State private var secondaryColor: Color = .purple

    private var labelStyle: MarkerLabelStyle {
        MarkerLabelStyle(placement: placement, anchor: anchor, distance: CGFloat(distance),
                   fontSize: CGFloat(fontSize), textColor: textColor, textStyle: textStyle,
                   outlineColor: outlineColor, outlineWidth: CGFloat(outlineWidth),
                   shape: labelShape, backgroundColor: background,
                   twoSegment: twoSegment, secondaryColor: secondaryColor)
    }

    /// The custom shape currently selected in the picker, if any.
    private var selectedCustom: CustomMarkerShape? {
        shapeStore.shapes.first { $0.id == customShapeID }
    }

    /// The shape actually drawn: the selected custom shape's base, or the predefined one.
    private var effectiveShape: MarkerShape { selectedCustom?.base ?? shape }

    /// The dimension overrides applied, from the selected custom shape (none otherwise).
    private var customization: ShapeCustomization {
        selectedCustom?.customization ?? ShapeCustomization()
    }

    private var style: MarkerStyle {
        MarkerStyle(shape: effectiveShape, symbol: symbol, fillColor: fill, glyphColor: glyph,
                    strokeColor: stroke, size: CGFloat(size), customization: customization,
                    label: showLabel ? labelStyle : nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        LinearGradient(colors: [.green.opacity(0.5), .teal.opacity(0.55)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        MarkerView(style: style, primaryText: primary,
                                   secondaryText: secondary, number: 3)
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                Section("Marker") {
                    Picker("Shape", selection: $shape) {
                        ForEach(MarkerShape.allCases) { Text($0.displayName).tag($0) }
                    }
                    .disabled(customShapeID != nil)
                    if !shapeStore.shapes.isEmpty {
                        Picker("Custom shape", selection: $customShapeID) {
                            Text("None (predefined)").tag(UUID?.none)
                            ForEach(shapeStore.shapes) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    if effectiveShape.showsGlyph {
                        Picker("Symbol", selection: $symbol) {
                            ForEach(MarkerSymbol.pickable) { Text($0.displayName).tag($0) }
                        }
                        ColorPicker("Symbol color", selection: $glyph, supportsOpacity: true)
                    }
                    ColorPicker("Fill color", selection: $fill, supportsOpacity: true)
                    ColorPicker("Border color", selection: $stroke, supportsOpacity: true)
                    slider("Size", $size, 8...44, step: 1)
                }

                Section("Label") {
                    Toggle("Show label", isOn: $showLabel)
                    if showLabel {
                        TextField("Primary text", text: $primary)
                        Picker("Placement", selection: $placement) {
                            ForEach(LabelPlacement.allCases) { Text($0.displayName).tag($0) }
                        }
                        if effectiveShape.hasSecondaryAnchor {
                            Picker("Attach to", selection: $anchor) {
                                ForEach(LabelAnchor.allCases) { Text($0.displayName).tag($0) }
                            }
                        }
                        if placement != .center {
                            slider("Distance", $distance, 0...28, step: 1)
                        }
                        slider("Text size", $fontSize, 8...22, step: 1)
                        ColorPicker("Text color", selection: $textColor, supportsOpacity: true)

                        Picker("Text style", selection: $textStyle) {
                            ForEach(LabelTextStyle.allCases) { Text($0.displayName).tag($0) }
                        }
                        if textStyle == .outlined {
                            ColorPicker("Outline color", selection: $outlineColor, supportsOpacity: true)
                            slider("Outline width", $outlineWidth, 0.5...4, step: 0.5)
                        }

                        Picker("Background", selection: $labelShape) {
                            ForEach(LabelShape.allCases) { Text($0.displayName).tag($0) }
                        }
                        if labelShape != .none {
                            ColorPicker("Background color", selection: $background, supportsOpacity: true)
                        }

                        Toggle("Two segments", isOn: $twoSegment)
                        if twoSegment {
                            TextField("Secondary text", text: $secondary)
                            ColorPicker("Second background", selection: $secondaryColor, supportsOpacity: true)
                        }
                    }
                }
            }
            .navigationTitle("Editor")
        }
    }

    private func slider(_ title: String, _ value: Binding<Double>,
                        _ range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(1))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
