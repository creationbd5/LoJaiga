import Foundation
import UIKit
import Vision

struct ParsedOffer {
    var fare: Double?
    var pickupMinutes: Double?
    var pickupKm: Double?
    var rideMinutes: Double?
    var rideKm: Double?
    var foundCount: Int {
        [fare, pickupMinutes, pickupKm, rideMinutes, rideKm].compactMap { $0 }.count
    }
}

/// Beta: reads text from a screenshot YOU provide and guesses the numbers.
/// Uber's layout varies by region/version and has not been verified here — always check the values.
enum OfferOCR {
    static func recognizeLines(in image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try handler.perform([request]) } catch { return [] }
            let obs = request.results ?? []
            return obs.compactMap { $0.topCandidates(1).first?.string }
        }.value
    }

    private static func groups(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { i in
                m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i))
            }
        }
    }

    static func parse(lines: [String]) -> ParsedOffer {
        let text = lines.joined(separator: " ")
        var out = ParsedOffer()

        // First dollar amount in reading order (offer price is the large figure at the top).
        if let g = groups(#"\$\s?(\d{1,3}(?:\.\d{1,2})?)"#, in: text).first, g.count > 1 {
            out.fare = Double(g[1])
        }

        // "9 min (4.2 km) away" and "38 min (32 km) trip"
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:mins?|minutes?)\s*\(?\s*(\d+(?:\.\d+)?)\s*(km|mi)\b\)?\s*(away|trip)?"#
        struct Pair { var min: Double; var km: Double; var label: String }
        var pairs: [Pair] = []
        for g in groups(pattern, in: text) where g.count >= 5 {
            guard let mins = Double(g[1]), let dist = Double(g[2]) else { continue }
            let km = g[3].lowercased() == "mi" ? dist * 1.60934 : dist
            pairs.append(Pair(min: mins, km: km, label: g[4].lowercased()))
        }
        if pairs.count >= 2 {
            let pickup = pairs.first(where: { $0.label == "away" }) ?? pairs[0]
            let ride = pairs.first(where: { $0.label == "trip" }) ?? pairs[1]
            out.pickupMinutes = pickup.min; out.pickupKm = pickup.km
            out.rideMinutes = ride.min; out.rideKm = ride.km
        } else if let only = pairs.first {
            if only.label == "trip" { out.rideMinutes = only.min; out.rideKm = only.km }
            else { out.pickupMinutes = only.min; out.pickupKm = only.km }
        }
        return out
    }
}
