import Foundation
import ReplayKit
import Vision
import CoreMedia
import UserNotifications

/// Experimental on-device OCR. No raw image or OCR text is saved.
final class SampleHandler: RPBroadcastSampleHandler {
    private var lastScan = Date.distantPast
    private let scanInterval: TimeInterval = 1.0
    private var lastOfferKey: String?
    private var lastOfferAt = Date.distantPast
    private var candidateKey: String?
    private var candidateCount = 0
    private var candidateAt = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastScan = .distantPast
        lastOfferKey = nil
        lastOfferAt = .distantPast
        candidateKey = nil
        candidateCount = 0
        candidateAt = .distantPast
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = Date()
        guard now.timeIntervalSince(lastScan) >= scanInterval else { return }
        lastScan = now
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        do {
            try VNImageRequestHandler(cvPixelBuffer: frame, options: [:]).perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            guard let offer = LiveOfferParser.parse(lines: lines) else {
                candidateKey = nil
                candidateCount = 0
                return
            }
            // Require the same fare and offer type in two consecutive OCR frames.
            // This reduces false positives; it can also miss very brief offers.
            if candidateKey == offer.fingerprint && now.timeIntervalSince(candidateAt) < 5 {
                candidateCount += 1
            } else {
                candidateKey = offer.fingerprint
                candidateCount = 1
            }
            candidateAt = now
            guard candidateCount >= 2 else { return }
            guard offer.fingerprint != lastOfferKey || now.timeIntervalSince(lastOfferAt) > 120 else { return }
            lastOfferKey = offer.fingerprint
            lastOfferAt = now
            notify(offer)
        } catch {
            NSLog("LoJaiga OCR failed: %@", error.localizedDescription)
        }
    }

    private func notify(_ offer: LiveOffer) {
        let content = UNMutableNotificationContent()
        content.title = "Lo Jaiga â€¢ Offer detected (TEST)"
        content.body = String(format: "$%.2f â€¢ %@ â€¢ Check Uber before accepting", offer.fare, offer.kind)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "offer-\(UUID().uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { NSLog("LoJaiga notification: %@", error.localizedDescription) }
        }
    }
}

private struct LiveOffer {
    let fare: Double
    let kind: String
    let fingerprint: String
}

/// Conservative provisional matcher. Real offers must be validated on device.
private enum LiveOfferParser {
    // Strong contextual markers only. Generic words like "accept", "pickup",
    // "matching" or "exclusive" do NOT identify Uber by themselves.
    static func parse(lines: [String]) -> LiveOffer? {
        let text = lines.joined(separator: " ")
        let lower = text.lowercased()
        let markers = ["uberx", "uber xl", "uberxl", "uber comfort", "uber green", "trip radar"]
        guard markers.contains(where: { lower.contains($0) }) else { return nil }

        // Require a displayed currency amount AND ride-specific distance/time.
        let distancePattern = #"\b\d+(?:[.,]\d+)?\s*(?:km|mi|miles)\b"#
        let timePattern = #"\b\d{1,3}\s*(?:min|mins|minutes)\b"#
        guard matches(distancePattern, in: lower),
              matches(timePattern, in: lower) else { return nil }

        let farePattern = #"(?:\$|cad\s*\$?)\s*(\d{1,3}(?:[.,]\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: farePattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let fare = Double(ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")),
              fare > 0, fare < 1000 else { return nil }

        let kind: String
        if lower.contains("trip radar") { kind = "Trip Radar" }
        else if lower.contains("uber comfort") { kind = "Uber Comfort" }
        else if lower.contains("uber xl") || lower.contains("uberxl") { kind = "UberXL" }
        else if lower.contains("uber green") { kind = "Uber Green" }
        else { kind = "UberX" }
        // A compact in-memory key, never persisted. OCR may fluctuate.
        let fingerprint = "\(kind):\(String(format: "%.2f", fare))"
        return LiveOffer(fare: fare, kind: kind, fingerprint: fingerprint)
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
