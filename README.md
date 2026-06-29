# MapMarkerKit

A small, flexible SwiftUI toolkit for drawing **markers** and **labels** on maps. It
provides a catalog of predefined marker styles (pin, circle, dot, balloon) and label
styles whose **shape is fixed** but whose **colors, symbol and label text are
user-selectable**. The same styles render identically through SwiftUI (live map) and
Core Graphics (static exports, thumbnails, share images).

Extracted from and used by the TravelMap app.

## Features

- **Predefined marker shapes** (`MarkerShape`): `teardrop` (a classic map pin),
  `circle`, `dot`, `balloon`. Shapes aren't user-editable — you build a marker by
  picking a style and customizing its colors, symbol and label.
- **User-selectable symbols** (`MarkerSymbol`): a palette of common SF Symbols plus a
  sequence-number option and `.custom("sf.symbol.name")`.
- **Flexible labels** (`LabelStyle`):
  - Placement: right / left / top / bottom / center.
  - **Anchor**: attach the label to the marker's **base point** (center of a circle,
    tip of a pin) or to a **secondary point** (the head of a pin, the body center of a
    balloon).
  - Background: pill, rectangular, or none.
  - Two-color **segments** (two adjacent strings on two background colors).
  - **Outlined text** — a fill color surrounded by a slim outline color, e.g. white
    text with a thin black outline, like a map caption (`LabelStyle.caption`).
- **Style catalog** (`MarkerCatalog`): the list of available marker and label styles,
  each with the capabilities it exposes (`MarkerCapabilities`) and a SwiftUI `preview`.
- **Matching Core Graphics renderer** (`MarkerRenderer`) so static images match the
  live map.

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/pilaski/MapMarkerKit.git", branch: "main")
```

Then add `MapMarkerKit` to your target's dependencies.

## Usage

### A marker on a MapKit annotation

```swift
import MapKit
import MapMarkerKit

let style = MarkerStyle(shape: .teardrop, symbol: .pin, fillColor: .purple,
                        label: LabelStyle(placement: .bottom))

Annotation("", coordinate: coordinate, anchor: style.shape.isBottomAnchored ? .bottom : .center) {
    MarkerView(style: style, primaryText: "Berlin")
}
```

### A two-color outlined caption

```swift
let captionStyle = MarkerStyle(shape: .circle, symbol: .none, fillColor: .red, size: 10,
                               label: .caption)
MarkerView(style: captionStyle, primaryText: "Summit")
```

### Browsing the catalog

```swift
ForEach(MarkerCatalog.markerStyles) { template in
    HStack {
        template.preview()
        VStack(alignment: .leading) {
            Text(template.name)
            Text(template.capabilities.descriptions.joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
```

### Static rendering (export)

```swift
MarkerRenderer.drawMarker(at: pointOnCanvas, style: style,
                          primary: "HAM", secondary: "Hamburg", in: cgContext)
```

## Example app

An example Swift Playgrounds app lives at
[`Examples/MapMarkerKitDemo.swiftpm`](Examples/MapMarkerKitDemo.swiftpm). Open it in
Swift Playgrounds (iPad/Mac) or Xcode — it depends on this package by relative path,
so it always builds against the local source. It has three tabs:

- **Catalog** — every predefined marker and label style with a live preview and the
  list of properties each one lets you change.
- **Editor** — interactively build a marker + label and see the result update live.
- **Map** — a real `MapKit` map showing the styles in place, including a pin whose
  label attaches to its tip (base) and a balloon whose label attaches to its body
  (secondary anchor).

## Platforms

iOS 17+. The SwiftUI views are cross-platform; `MarkerRenderer` and color resolution
use UIKit and are gated to UIKit platforms.

## License

See repository.
