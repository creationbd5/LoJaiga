import Foundation
import MapKit

enum GeoService {
    struct Match { let name: String; let lat: Double; let lon: Double }

    /// Search bias only (Greater Toronto Area). Results outside the region can still be returned.
    private static let biasCenter = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

    static func search(_ query: String) async -> Match? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.region = MKCoordinateRegion(center: biasCenter, latitudinalMeters: 150_000, longitudinalMeters: 150_000)
        do {
            let response = try await MKLocalSearch(request: req).start()
            guard let item = response.mapItems.first else { return nil }
            let c = item.placemark.coordinate
            return Match(name: item.name ?? q, lat: c.latitude, lon: c.longitude)
        } catch {
            return nil
        }
    }
}
