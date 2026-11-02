import Foundation
import CoreLocation

/// Pure, side-effect-free offer scoring. Unit-tested in LoJaigaTests.
enum OfferEvaluator {
    static func distanceKm(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
        CLLocation(latitude: aLat, longitude: aLon).distance(from: CLLocation(latitude: bLat, longitude: bLon)) / 1000
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        let n = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !n.isEmpty && haystack.localizedCaseInsensitiveContains(n)
    }

    /// True when the offer's destination is inside `place`. Uses real distance only when BOTH sides are geocoded; otherwise falls back to name matching.
    private static func destinationInside(_ offer: TripOffer, _ place: PlaceRule) -> (hit: Bool, usedCoordinates: Bool) {
        if let oLat = offer.destLat, let oLon = offer.destLon, let pLat = place.lat, let pLon = place.lon {
            return (distanceKm(oLat, oLon, pLat, pLon) <= place.radiusKm, true)
        }
        return (contains(offer.destination, place.name), false)
    }

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }

    static func evaluate(_ offer: TripOffer, prefs: Preferences) -> Evaluation {
        var problems: [String] = []
        var goods: [String] = []
        var notes: [String] = []
        let eps = 1e-9

        let cost = offer.totalKm * prefs.operatingCostKm
        let net = offer.fare - cost
        let netPerHour = offer.totalMinutes > 0 ? net * 60 / offer.totalMinutes : 0

        guard offer.fare > 0, offer.totalMinutes > 0 else {
            return Evaluation(verdict: .incomplete, score: 0, problems: [],
                              goods: [], notes: ["Enter the fare and the pickup + trip minutes."],
                              estimatedNet: net, netPerHour: netPerHour)
        }

        // 1. Fare
        if offer.fare + eps < prefs.minFare { problems.append("Fare is below your minimum") }
        else { goods.append("Fare meets your minimum") }

        // 2. $/km (skipped, not failed, if distance is missing)
        if offer.totalKm > 0 {
            if offer.perKm + eps < prefs.minPerKm { problems.append("Low fare per km") }
            else { goods.append("Strong fare per km") }
        } else {
            notes.append("Distance missing — $/km not checked.")
        }

        // 3. $/hour
        if offer.perHour + eps < prefs.minPerHour { problems.append("Low hourly rate") }
        else { goods.append("Good hourly rate") }

        // 4. Pickup
        if offer.pickupMinutes > prefs.maxPickupMinutes + eps { problems.append("Pickup is too far") }
        else { goods.append("Pickup is close") }

        // 5. Preferred destinations
        if !prefs.anyDestination {
            let wanted = prefs.preferred.filter { !$0.isEmpty }
            if wanted.isEmpty {
                problems.append("Destination filter is on but no preferred areas are set")
            } else {
                var inside = false
                var textOnly = false
                for place in wanted {
                    let r = destinationInside(offer, place)
                    if r.hit { inside = true; if !r.usedCoordinates { textOnly = true } }
                }
                if inside {
                    goods.append("Drop-off is in a preferred area")
                    if textOnly { notes.append("Drop-off matched by name only (not located on the map).") }
                } else {
                    problems.append("Drop-off is not in a preferred area")
                }
            }
        }

        // 6. Avoid list
        for place in prefs.avoid where !place.isEmpty {
            let r = destinationInside(offer, place)
            let routeHit = contains(offer.routeDescription, place.name)
            if r.hit || routeHit {
                problems.append("Avoided area/road: \(place.name)")
                if r.hit && !r.usedCoordinates { notes.append("“\(place.name)” matched by name only.") }
            }
        }

        // Score (0-100)
        func ratio(_ v: Double, _ target: Double) -> Double { target <= 0 ? 1 : clamp01(v / (target * 1.25)) }
        let hourS = ratio(offer.perHour, prefs.minPerHour)
        let kmS = offer.totalKm > 0 ? ratio(offer.perKm, prefs.minPerKm) : hourS
        let fareS = ratio(offer.fare, prefs.minFare)
        let m = max(prefs.maxPickupMinutes, 1)
        let p = offer.pickupMinutes
        let pickS = p <= m ? 1 - 0.2 * (p / m) : max(0, 0.8 * (1 - (p - m) / m))
        var score = Int(((hourS * 0.35 + kmS * 0.25 + fareS * 0.15 + pickS * 0.25) * 100).rounded())
        score = min(max(score, 0), 100)
        if problems.isEmpty { score = max(score, 60) } else { score = min(score, 59) }

        return Evaluation(verdict: problems.isEmpty ? .good : .bad, score: score,
                          problems: problems, goods: goods, notes: notes,
                          estimatedNet: net, netPerHour: netPerHour)
    }
}

enum OfferSpeech {
    static func summary(_ o: TripOffer, _ e: Evaluation) -> String {
        func f(_ v: Double) -> String { String(format: "%.2f", v) }
        switch e.verdict {
        case .incomplete:
            return "No offer loaded. Enter the fare and times first."
        case .good:
            return "Good offer. Match score \(e.score). Fare \(f(o.fare)) dollars. \(f(o.perKm)) dollars per kilometre. \(f(o.perHour)) dollars per hour. Pickup \(Int(o.pickupMinutes.rounded())) minutes."
        case .bad:
            return "Bad offer. " + e.problems.joined(separator: ". ") + ". Fare \(f(o.fare)) dollars."
        }
    }
}
