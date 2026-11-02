import UIKit

enum MapLauncher {
    static func url(name: String, lat: Double?, lon: Double?, provider: String, avoidTolls: Bool) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var coord: String? = nil
        if let lat = lat, let lon = lon { coord = "\(lat),\(lon)" }
        guard coord != nil || !trimmed.isEmpty else { return nil }
        let target = coord ?? trimmed

        var c = URLComponents()
        c.scheme = "https"
        switch provider {
        case "Waze":
            c.host = "waze.com"
            c.path = "/ul"
            c.queryItems = [URLQueryItem(name: coord != nil ? "ll" : "q", value: target),
                            URLQueryItem(name: "navigate", value: "yes")]
        case "Apple Maps":
            // Apple Maps URLs have no documented "avoid tolls" switch.
            c.host = "maps.apple.com"
            c.path = "/"
            c.queryItems = [URLQueryItem(name: "daddr", value: target),
                            URLQueryItem(name: "dirflg", value: "d")]
        default:
            c.host = "www.google.com"
            c.path = "/maps/dir/"
            var items = [URLQueryItem(name: "api", value: "1"),
                         URLQueryItem(name: "destination", value: target),
                         URLQueryItem(name: "travelmode", value: "driving"),
                         URLQueryItem(name: "dir_action", value: "navigate")]
            if avoidTolls { items.append(URLQueryItem(name: "avoid", value: "tolls")) }
            c.queryItems = items
        }
        return c.url
    }

    static func open(name: String, lat: Double?, lon: Double?, provider: String, avoidTolls: Bool) {
        guard let u = url(name: name, lat: lat, lon: lon, provider: provider, avoidTolls: avoidTolls) else { return }
        UIApplication.shared.open(u)
    }
}
