import AVFoundation

/// Text-to-speech for offer verdicts. (Speaking is supported; this is separate from listening.)
final class VoiceService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceService()
    private let speaker = AVSpeechSynthesizer()
    private(set) var lastText = ""
    /// Called on the main queue when speech starts/stops so the listener can ignore our own voice.
    var onSpeakingChanged: ((Bool) -> Void)?
    /// True while VoiceCommandEngine owns the audio session (play-and-record).
    var sessionManagedElsewhere = false

    override init() {
        super.init()
        speaker.delegate = self
    }

    func say(_ text: String, language: String = "en-US", remember: Bool = true) {
        if remember { lastText = text }
        if !sessionManagedElsewhere {
            let s = AVAudioSession.sharedInstance()
            try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? s.setActive(true)
        }
        speaker.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")
        u.rate = 0.49
        speaker.speak(u)
    }

    func repeatLast(language: String = "en-US") {
        guard !lastText.isEmpty else { return }
        say(lastText, language: language, remember: false)
    }

    func stop() { speaker.stopSpeaking(at: .immediate) }

    private func finished() {
        DispatchQueue.main.async {
            self.onSpeakingChanged?(false)
            if !self.sessionManagedElsewhere {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onSpeakingChanged?(true) }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { finished() }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { finished() }
}
