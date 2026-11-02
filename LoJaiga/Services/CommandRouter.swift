import Foundation

/// Maps the 10 voice slots to actions INSIDE Lo Jaiga. None of these actions touch the Uber app.
final class CommandRouter {
    private unowned let store: TripStore
    init(store: TripStore) { self.store = store }

    func handle(index: Int) {
        let lang = store.prefs.voiceLanguage
        func say(_ t: String) { VoiceService.shared.say(t, language: lang) }
        let o = store.current
        let e = store.evaluate(o)
        let hasOffer = e.verdict != .incomplete

        switch index {
        case 0: // Lo Jaiga
            say("Yes boss. Listening.")
        case 1: // Baad Dey -> log as skipped locally
            guard hasOffer else { say("No offer loaded."); return }
            store.log(.skipped)
            store.current = TripOffer()
            say("Logged as skipped. Decline it in Uber yourself.")
        case 2: // Koi Jamu -> destination
            say(o.destination.isEmpty ? "No destination entered." : "Destination is \(o.destination).")
        case 3: // Trip Koi -> trip facts
            guard hasOffer else { say("No offer loaded."); return }
            say("Pickup \(Int(o.pickupMinutes.rounded())) minutes. Trip \(String(format: "%.1f", o.rideKm)) kilometres, \(Int(o.rideMinutes.rounded())) minutes.")
        case 4: // Map ON Kor
            if o.destination.isEmpty && !o.hasCoordinate { say("No destination entered."); return }
            MapLauncher.open(name: o.destination, lat: o.destLat, lon: o.destLon,
                             provider: store.prefs.mapApp, avoidTolls: store.prefs.avoidTolls)
            say("Opening maps.")
        case 5: // Koto Taka
            guard hasOffer else { say("No offer loaded."); return }
            say("Fare \(String(format: "%.2f", o.fare)) dollars. \(String(format: "%.2f", o.perKm)) per kilometre. \(String(format: "%.0f", o.perHour)) per hour.")
        case 6: // Bari Jamu
            let h = store.prefs.home
            if h.isEmpty && !h.hasCoordinate { say("Home is not set. Set it in Settings, Places."); return }
            MapLauncher.open(name: h.name, lat: h.lat, lon: h.lon,
                             provider: store.prefs.mapApp, avoidTolls: store.prefs.avoidTolls)
            say("Navigating home.")
        case 7: // Chup Thak
            VoiceService.shared.stop()
        case 8: // Abar Bol
            VoiceService.shared.repeatLast(language: lang)
        case 9: // Offer Dekha -> verdict
            say(OfferSpeech.summary(o, e))
        default:
            break
        }
    }
}
