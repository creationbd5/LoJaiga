import Foundation
import CoreLocation

// MARK: - Tolerant decoding helper (older saved data never crashes or wipes newer fields)
extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

enum TripStatus: String, Codable, CaseIterable {
    case reviewed, taken, skipped, completed
    var label: String {
        switch self {
        case .reviewed: return "Reviewed"
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .completed: return "Completed"
        }
    }
    var countsAsEarning: Bool { self == .taken || self == .completed }
}

// MARK: - Place rule (preferred / avoid / home)
struct PlaceRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var radiusKm: Double = 5
    var lat: Double? = nil
    var lon: Double? = nil
    var resolvedName: String? = nil
    var locatedFor: String? = nil

    var isEmpty: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasCoordinate: Bool { lat != nil && lon != nil }

    enum CodingKeys: String, CodingKey { case id, name, radiusKm, lat, lon, resolvedName, locatedFor }
}

extension PlaceRule {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, id)
        name = c.value(.name, name)
        radiusKm = c.value(.radiusKm, radiusKm)
        lat = try? c.decodeIfPresent(Double.self, forKey: .lat)
        lon = try? c.decodeIfPresent(Double.self, forKey: .lon)
        resolvedName = try? c.decodeIfPresent(String.self, forKey: .resolvedName)
        locatedFor = try? c.decodeIfPresent(String.self, forKey: .locatedFor)
    }
}

// MARK: - Offer
struct TripOffer: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var fare: Double = 0
    var pickupKm: Double = 0
    var pickupMinutes: Double = 0
    var rideKm: Double = 0
    var rideMinutes: Double = 0
    var destination: String = ""
    var routeDescription: String = ""
    var destLat: Double? = nil
    var destLon: Double? = nil
    var resolvedName: String? = nil
    var status: TripStatus = .reviewed
    var score: Int? = nil
    var wasGood: Bool? = nil

    var totalKm: Double { pickupKm + rideKm }
    var totalMinutes: Double { pickupMinutes + rideMinutes }
    var perKm: Double { totalKm > 0 ? fare / totalKm : 0 }
    var perHour: Double { totalMinutes > 0 ? fare * 60 / totalMinutes : 0 }
    var hasCoordinate: Bool { destLat != nil && destLon != nil }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, fare, pickupKm, pickupMinutes, rideKm, rideMinutes
        case destination, routeDescription, destLat, destLon, resolvedName, status, score, wasGood
    }
}

extension TripOffer {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, id)
        createdAt = c.value(.createdAt, createdAt)
        fare = c.value(.fare, fare)
        pickupKm = c.value(.pickupKm, pickupKm)
        pickupMinutes = c.value(.pickupMinutes, pickupMinutes)
        rideKm = c.value(.rideKm, rideKm)
        rideMinutes = c.value(.rideMinutes, rideMinutes)
        destination = c.value(.destination, destination)
        routeDescription = c.value(.routeDescription, routeDescription)
        destLat = try? c.decodeIfPresent(Double.self, forKey: .destLat)
        destLon = try? c.decodeIfPresent(Double.self, forKey: .destLon)
        resolvedName = try? c.decodeIfPresent(String.self, forKey: .resolvedName)
        status = c.value(.status, status)
        score = try? c.decodeIfPresent(Int.self, forKey: .score)
        wasGood = try? c.decodeIfPresent(Bool.self, forKey: .wasGood)
    }
}

// MARK: - Preferences
struct Preferences: Codable, Equatable {
    static let defaultCommands = ["Lo Jaiga", "Baad Dey", "Koi Jamu", "Trip Koi", "Map ON Kor",
                                  "Koto Taka", "Bari Jamu", "Chup Thak", "Abar Bol", "Offer Dekha"]
    var minFare: Double = 15
    var minPerKm: Double = 1.5
    var minPerHour: Double = 25
    var maxPickupMinutes: Double = 12
    var operatingCostKm: Double = 0.25
    var anyDestination: Bool = true
    var preferred: [PlaceRule] = (0..<5).map { _ in PlaceRule() }
    var avoid: [PlaceRule] = (0..<5).map { _ in PlaceRule() }
    var home = PlaceRule(radiusKm: 1)
    var mapApp: String = "Google Maps"
    var avoidTolls: Bool = true
    var voiceEnabled: Bool = true
    var voiceLanguage: String = "en-US"
    var voiceCommands: [String] = Preferences.defaultCommands
    var ownerVoiceGate: Bool = false

    enum CodingKeys: String, CodingKey {
        case minFare, minPerKm, minPerHour, maxPickupMinutes, operatingCostKm, anyDestination
        case preferred, avoid, home, mapApp, avoidTolls, voiceEnabled, voiceLanguage, voiceCommands, ownerVoiceGate
    }
}

private func fitPlaces(_ a: [PlaceRule], _ n: Int) -> [PlaceRule] {
    var r = Array(a.prefix(n))
    while r.count < n { r.append(PlaceRule()) }
    return r
}

extension Preferences {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minFare = c.value(.minFare, minFare)
        minPerKm = c.value(.minPerKm, minPerKm)
        minPerHour = c.value(.minPerHour, minPerHour)
        maxPickupMinutes = c.value(.maxPickupMinutes, maxPickupMinutes)
        operatingCostKm = c.value(.operatingCostKm, operatingCostKm)
        anyDestination = c.value(.anyDestination, anyDestination)
        preferred = fitPlaces(c.value(.preferred, preferred), 5)
        avoid = fitPlaces(c.value(.avoid, avoid), 5)
        home = c.value(.home, home)
        mapApp = c.value(.mapApp, mapApp)
        avoidTolls = c.value(.avoidTolls, avoidTolls)
        voiceEnabled = c.value(.voiceEnabled, voiceEnabled)
        voiceLanguage = c.value(.voiceLanguage, voiceLanguage)
        var cmds: [String] = c.value(.voiceCommands, voiceCommands)
        while cmds.count < 10 { cmds.append(Preferences.defaultCommands[cmds.count]) }
        voiceCommands = Array(cmds.prefix(10))
        ownerVoiceGate = c.value(.ownerVoiceGate, ownerVoiceGate)
    }
}

// MARK: - Evaluation result
enum Verdict { case good, bad, incomplete }

struct Evaluation {
    var verdict: Verdict
    var score: Int
    var problems: [String]
    var goods: [String]
    var notes: [String]
    var estimatedNet: Double
    var netPerHour: Double
    var matched: Bool { verdict == .good }
}
