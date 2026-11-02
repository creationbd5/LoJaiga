import XCTest
@testable import LoJaiga

final class OfferEvaluatorTests: XCTestCase {
    private func prefs() -> Preferences {
        var p = Preferences()
        p.minFare = 15; p.minPerKm = 1.5; p.minPerHour = 25; p.maxPickupMinutes = 12
        p.anyDestination = true
        return p
    }
    private func offer(fare: Double, pk: Double = 3, pm: Double = 8, rk: Double = 12, rm: Double = 22) -> TripOffer {
        var o = TripOffer()
        o.fare = fare; o.pickupKm = pk; o.pickupMinutes = pm; o.rideKm = rk; o.rideMinutes = rm
        return o
    }

    func testGoodOffer() {
        let e = OfferEvaluator.evaluate(offer(fare: 30), prefs: prefs())
        XCTAssertEqual(e.verdict, .good)
        XCTAssertGreaterThanOrEqual(e.score, 60)
        XCTAssertTrue(e.problems.isEmpty)
    }

    func testExactBoundariesPass() {
        // fare 15, 10 km, 36 min -> exactly $1.50/km and $25/hr
        let e = OfferEvaluator.evaluate(offer(fare: 15, pk: 2, pm: 6, rk: 8, rm: 30), prefs: prefs())
        XCTAssertEqual(e.verdict, .good)
    }

    func testJustBelowFareFails() {
        let e = OfferEvaluator.evaluate(offer(fare: 14.99, pk: 2, pm: 6, rk: 8, rm: 30), prefs: prefs())
        XCTAssertEqual(e.verdict, .bad)
        XCTAssertTrue(e.problems.contains { $0.contains("Fare") })
    }

    func testPickupTooLong() {
        let e = OfferEvaluator.evaluate(offer(fare: 40, pm: 13), prefs: prefs())
        XCTAssertEqual(e.verdict, .bad)
        XCTAssertTrue(e.problems.contains { $0.contains("Pickup") })
    }

    func testZeroDistanceSkipsPerKmButStillEvaluates() {
        let e = OfferEvaluator.evaluate(offer(fare: 20, pk: 0, pm: 5, rk: 0, rm: 20), prefs: prefs())
        XCTAssertEqual(e.verdict, .good)
        XCTAssertTrue(e.notes.contains { $0.contains("Distance") })
    }

    func testZeroTimeOrFareIsIncomplete() {
        XCTAssertEqual(OfferEvaluator.evaluate(offer(fare: 0), prefs: prefs()).verdict, .incomplete)
        XCTAssertEqual(OfferEvaluator.evaluate(offer(fare: 20, pm: 0, rm: 0), prefs: prefs()).verdict, .incomplete)
    }

    func testDestinationFilterOnWithNoPlacesFails() {
        var p = prefs(); p.anyDestination = false
        let e = OfferEvaluator.evaluate(offer(fare: 30), prefs: p)
        XCTAssertEqual(e.verdict, .bad)
    }

    func testPreferredByNameOnly() {
        var p = prefs(); p.anyDestination = false
        p.preferred[0] = PlaceRule(name: "Scarborough")
        var o = offer(fare: 30)
        o.destination = "Scarborough Town Centre"
        let hit = OfferEvaluator.evaluate(o, prefs: p)
        XCTAssertEqual(hit.verdict, .good)
        XCTAssertTrue(hit.notes.contains { $0.contains("name only") })
        o.destination = "Mississauga"
        XCTAssertEqual(OfferEvaluator.evaluate(o, prefs: p).verdict, .bad)
    }

    func testAvoidedRoadInRouteText() {
        var p = prefs()
        p.avoid[0] = PlaceRule(name: "Highway 401")
        var o = offer(fare: 30)
        o.routeDescription = "via Highway 401 east"
        let e = OfferEvaluator.evaluate(o, prefs: p)
        XCTAssertEqual(e.verdict, .bad)
        XCTAssertTrue(e.problems.contains { $0.contains("Highway 401") })
    }

    func testPreferredRadiusUsesCoordinates() {
        var p = prefs(); p.anyDestination = false
        p.preferred[0] = PlaceRule(name: "Scarborough", radiusKm: 5, lat: 43.7764, lon: -79.2318)
        var near = offer(fare: 30)
        near.destination = "Somewhere else by name"
        near.destLat = 43.78; near.destLon = -79.23
        XCTAssertEqual(OfferEvaluator.evaluate(near, prefs: p).verdict, .good)

        var far = offer(fare: 30)
        far.destination = "Scarborough"          // name matches, but coordinates are ~20 km away
        far.destLat = 43.6532; far.destLon = -79.3832
        XCTAssertEqual(OfferEvaluator.evaluate(far, prefs: p).verdict, .bad)
    }

    func testAvoidRadiusUsesCoordinates() {
        var p = prefs()
        p.avoid[0] = PlaceRule(name: "Downtown", radiusKm: 2, lat: 43.6532, lon: -79.3832)
        var o = offer(fare: 30)
        o.destination = "King St"
        o.destLat = 43.655; o.destLon = -79.38
        XCTAssertEqual(OfferEvaluator.evaluate(o, prefs: p).verdict, .bad)
    }

    func testScoreIsBounded() {
        let e = OfferEvaluator.evaluate(offer(fare: 500), prefs: prefs())
        XCTAssertTrue((0...100).contains(e.score))
    }

    func testOldSavedDataStillDecodes() throws {
        let json = #"{"fare": 22.5, "destination": "Oshawa"}"#.data(using: .utf8)!
        let o = try JSONDecoder().decode(TripOffer.self, from: json)
        XCTAssertEqual(o.fare, 22.5)
        XCTAssertEqual(o.destination, "Oshawa")
        let p = try JSONDecoder().decode(Preferences.self, from: "{}".data(using: .utf8)!)
        XCTAssertEqual(p.voiceCommands.count, 10)
        XCTAssertEqual(p.preferred.count, 5)
    }

    func testVoiceMatcherFuzzy() {
        let cmds = Preferences.defaultCommands
        let m = VoiceMatcher.best(transcript: "hey bad dey", commands: cmds, aliases: [])
        XCTAssertEqual(m?.index, 1)
        XCTAssertNil(VoiceMatcher.best(transcript: "nice weather today", commands: cmds, aliases: []))
    }

    func testOCRParse() {
        let p = OfferOCR.parse(lines: ["$42.75", "9 min (4.2 km) away", "38 min (32 km) trip"])
        XCTAssertEqual(p.fare, 42.75)
        XCTAssertEqual(p.pickupMinutes, 9)
        XCTAssertEqual(p.rideKm ?? 0, 32, accuracy: 0.01)
    }
}
