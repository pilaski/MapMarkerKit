import SwiftUI
import MapKit
import CoreLocation
import MapMarkerKit

/// A pin to render on the demo map.
private struct DemoPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let style: MarkerStyle
    var primary: String? = nil
    var secondary: String? = nil
    var number: Int? = nil
}

/// A live `MapKit` map showing several MarkerKit styles, including a pin whose label
/// attaches to its base (tip) and a balloon whose label attaches to its body — the
/// two label-anchor options the kit offers.
struct MapDemoView: View {
    private let pins: [DemoPin] = [
        DemoPin(coordinate: .init(latitude: 52.520, longitude: 13.405),
                style: MarkerStyle(shape: .teardrop, symbol: .pin, fillColor: .purple,
                                   label: MarkerLabelStyle(placement: .bottom, anchor: .base,
                                                     textColor: .white, textStyle: .outlined, shape: .none)),
                primary: "Berlin"),
        DemoPin(coordinate: .init(latitude: 53.551, longitude: 9.994),
                style: MarkerStyle(shape: .circle, symbol: .airplane, fillColor: .orange, size: 22,
                                   label: MarkerLabelStyle(placement: .right,
                                                     backgroundColor: .white.opacity(0.9),
                                                     twoSegment: true,
                                                     secondaryColor: .orange.opacity(0.9))),
                primary: "HAM", secondary: "Hamburg"),
        DemoPin(coordinate: .init(latitude: 48.137, longitude: 11.575),
                style: MarkerStyle(shape: .balloon, symbol: .star, fillColor: .teal,
                                   label: MarkerLabelStyle(placement: .right, anchor: .secondary,
                                                     textColor: .primary, shape: .pill)),
                primary: "Munich"),
        DemoPin(coordinate: .init(latitude: 50.110, longitude: 8.682),
                style: MarkerStyle(shape: .teardrop, symbol: .number, fillColor: .blue,
                                   label: MarkerLabelStyle(placement: .top, anchor: .secondary,
                                                     textColor: .white, textStyle: .outlined, shape: .none)),
                primary: "Stop 4", number: 4),
        DemoPin(coordinate: .init(latitude: 51.339, longitude: 12.377),
                style: MarkerStyle(shape: .dot, fillColor: .red, size: 13,
                                   label: MarkerLabelStyle(placement: .right, textColor: .primary, shape: .rectangular)),
                primary: "Leipzig")
    ]

    private let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.3, longitude: 11.0),
        span: MKCoordinateSpan(latitudeDelta: 6.5, longitudeDelta: 6.5))

    var body: some View {
        Map(initialPosition: .region(initialRegion)) {
            ForEach(pins) { pin in
                Annotation("", coordinate: pin.coordinate,
                           anchor: pin.style.shape.isBottomAnchored ? .bottom : .center) {
                    MarkerView(style: pin.style, primaryText: pin.primary,
                               secondaryText: pin.secondary, number: pin.number)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}
