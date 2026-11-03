import SwiftUI
import MapKit

/// Pick a preferred destination or avoid area by searchable Apple Maps result,
/// or by long-pressing a location on the map. This does not access Uber's route.
struct PlaceMapPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var place: PlaceRule
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
                           span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)))
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var chosen: CLLocationCoordinate2D?
    @State private var chosenName = ""
    @State private var searching = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search road, address, neighbourhood", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit { Task { await lookup() } }
                Button("Search") { Task { await lookup() } }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if !results.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            Button(item.name ?? "Location") { choose(item) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxHeight: 50)
            }

            MapReader { proxy in
                Map(position: $camera) {
                    if let chosen {
                        Annotation(chosenName.isEmpty ? "Selected" : chosenName, coordinate: chosen) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.mint)
                        }
                    }
                }
                .mapControls { MapCompass(); MapScaleView() }
                .onLongPressGesture(minimumDuration: 0.55) { }
                .simultaneousGesture(SpatialTapGesture(count: 1).onEnded { value in
                    if let coordinate = proxy.convert(value.location, from: .local) {
                        chosen = coordinate
                        chosenName = query.isEmpty ? "Pinned location" : query
                    }
                })
            }
            .frame(maxHeight: .infinity)

            Text("Search and choose a result, or tap the map to set a pin. Check the location before saving.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Save selected location") {
                guard let chosen else { return }
                place.lat = chosen.latitude
                place.lon = chosen.longitude
                place.name = chosenName
                place.resolvedName = chosenName
                place.locatedFor = chosenName
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(chosen == nil)
        }
        .padding()
        .navigationTitle("Select on Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let lat = place.lat, let lon = place.lon {
                chosen = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                chosenName = place.name
                camera = .region(MKCoordinateRegion(center: chosen!, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
        }
    }

    @MainActor private func lookup() async {
        searching = true
        defer { searching = false }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
                                        latitudinalMeters: 120_000, longitudinalMeters: 120_000)
        results = (try? await MKLocalSearch(request: req).start().mapItems) ?? []
        if let item = results.first { choose(item) }
    }
    private func choose(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        chosen = c
        chosenName = item.name ?? query
        camera = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
    }
}
