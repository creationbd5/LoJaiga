import Foundation

/// Two local voice actions. No automatic tap/accept of Uber's interface.
final class CommandRouter {
    private unowned let store: TripStore
    init(store: TripStore) { self.store = store }

    func handle(index: Int) {
        let result = store.evaluate(store.current)
        let language = store.prefs.voiceLanguage
        if index == 0 {
            guard result.verdict != .incomplete else {
                VoiceService.shared.say("No offer has been loaded. Open Analyze and import a screenshot first.", language: language)
                return
            }
            VoiceService.shared.say(OfferSpeech.summary(store.current, result) + ". Review and press Accept in Uber yourself.", language: language)
        } else if index == 1 {
            guard result.verdict != .incomplete else { return }
            store.log(.skipped)
            store.current = TripOffer()
            VoiceService.shared.say("Offer ignored in Lo Jaiga. Uber has not been tapped.", language: language)
        }
    }
}
