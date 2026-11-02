import AppIntents
import UIKit
import UniformTypeIdentifiers

/// Shortcuts action: Take Screenshot → "Check Offer Screenshot" → Speak Text.
/// You trigger it (Action Button / Back Tap / Siri). It only reads the image you pass in and returns text.
struct AnalyzeOfferScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Offer Screenshot"

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let prefs = Persistence.load(Preferences.self, name: "prefs.json") ?? Preferences()
        guard let image = UIImage(data: screenshot.data) else {
            return .result(value: "I couldn't open that image.")
        }
        let lines = await OfferOCR.recognizeLines(in: image)
        let parsed = OfferOCR.parse(lines: lines)
        guard let fare = parsed.fare, parsed.foundCount >= 3 else {
            return .result(value: "I couldn't read the offer clearly. Check it manually.")
        }
        var offer = TripOffer()
        offer.fare = fare
        offer.pickupMinutes = parsed.pickupMinutes ?? 0
        offer.pickupKm = parsed.pickupKm ?? 0
        offer.rideMinutes = parsed.rideMinutes ?? 0
        offer.rideKm = parsed.rideKm ?? 0
        let eval = OfferEvaluator.evaluate(offer, prefs: prefs)
        return .result(value: OfferSpeech.summary(offer, eval) + " Verify before deciding.")
    }
}
