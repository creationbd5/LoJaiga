import Foundation
import AVFoundation
import Speech

// MARK: - Enrollment data (features only; raw audio is never stored)
struct VoiceSlot: Codable, Equatable {
    var aliases: [String] = []     // how the recognizer transcribed the owner saying this command
    var profile: [Double]? = nil   // averaged spectral features of that take
    var takes: Int = 0
}

struct VoiceEnrollment: Codable, Equatable {
    var slots: [VoiceSlot] = (0..<10).map { _ in VoiceSlot() }
    var ownerProfile: [Double] = []
    var threshold: Double = 0.6
    var enrolledAt: Date? = nil
    var completed: Bool { slots.count >= 10 && slots.allSatisfy { $0.profile != nil } }
    var enrolledCount: Int { slots.filter { $0.profile != nil }.count }
}

// MARK: - Audio features (crude long-term spectral shape; NOT a secure voiceprint)
enum FeatureExtractor {
    static let bands: [Double] = {
        let n = 20
        let lo = 150.0, hi = 4000.0
        return (0..<n).map { lo * pow(hi / lo, Double($0) / Double(n - 1)) }
    }()

    /// One feature vector for a voiced audio buffer, or nil if the buffer is quiet.
    static func frameVector(_ buffer: AVAudioPCMBuffer) -> [Double]? {
        guard let ch = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        guard n > 256 else { return nil }
        let sr = buffer.format.sampleRate
        guard sr > 0 else { return nil }

        var xs = [Double](repeating: 0, count: n)
        var sum = 0.0
        for i in 0..<n {
            let w = 0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(n - 1))
            let x = Double(ch[i])
            sum += x * x
            xs[i] = x * w
        }
        let rms = (sum / Double(n)).squareRoot()
        guard rms > 0.008 else { return nil }

        var out = [Double](repeating: 0, count: bands.count)
        for (bi, f) in bands.enumerated() {
            let k = 2 * cos(2 * Double.pi * f / sr)
            var s1 = 0.0, s2 = 0.0
            for i in 0..<n {
                let s = xs[i] + k * s1 - s2
                s2 = s1
                s1 = s
            }
            let power = s1 * s1 + s2 * s2 - k * s1 * s2
            out[bi] = log10(max(power, 1e-12))
        }
        let mean = out.reduce(0, +) / Double(out.count)
        return out.map { $0 - mean }   // remove overall loudness
    }

    static func mean(_ vs: [[Double]]) -> [Double] {
        guard let first = vs.first else { return [] }
        var acc = [Double](repeating: 0, count: first.count)
        for v in vs where v.count == first.count {
            for i in 0..<v.count { acc[i] += v[i] }
        }
        return acc.map { $0 / Double(vs.count) }
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        let d = (na.squareRoot() * nb.squareRoot())
        return d > 0 ? dot / d : 0
    }
}

// MARK: - Fuzzy command matching
enum VoiceMatcher {
    struct Match { let index: Int; let score: Double }

    static func normalize(_ s: String) -> String {
        let chars: [Character] = s.lowercased().unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : " "
        }
        return String(chars).split(separator: " ").joined(separator: " ")
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 1 }
        if x.isEmpty || y.isEmpty { return 0 }
        var prev = Array(0...y.count)
        for i in 1...x.count {
            var cur = [i] + [Int](repeating: 0, count: y.count)
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            prev = cur
        }
        return 1 - Double(prev[y.count]) / Double(max(x.count, y.count))
    }

    /// Looks at the END of the transcript (what was just said) and finds the closest command or learned alias.
    static func best(transcript: String, commands: [String], aliases: [[String]]) -> Match? {
        let words = normalize(transcript).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        var best: Match? = nil
        for (i, cmd) in commands.enumerated() {
            var variants = [normalize(cmd)]
            if i < aliases.count { variants += aliases[i].map { normalize($0) } }
            for v in variants where !v.isEmpty {
                let n = v.split(separator: " ").count
                for len in Set([n, n + 1, max(1, n - 1)]) where words.count >= len {
                    let tail = words.suffix(len).joined(separator: " ")
                    let s = similarity(tail, v)
                    if s >= 0.80 && s > (best?.score ?? 0) { best = Match(index: i, score: s) }
                }
            }
        }
        return best
    }
}

// MARK: - Engine
/// Foreground voice commands + owner-voice enrollment.
/// Call all methods from the main thread.
final class VoiceCommandEngine: ObservableObject {
    static let shared = VoiceCommandEngine()

    enum Mode: Equatable { case idle, listening, enrolling(Int) }

    @Published var mode: Mode = .idle
    @Published var status: String = "Voice control is off"
    @Published var heard: String = ""
    @Published var lastAction: String = ""
    @Published var permissionMessage: String? = nil
    @Published var enrollment = VoiceEnrollment()

    weak var store: TripStore?
    var onCommand: ((Int) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = 0
    private var frames: [[Double]] = []
    private var enrollTranscript = ""
    private var lastFire = Date.distantPast
    private var ignoreInput = false
    private var restartScheduled = false

    init() {
        if var e = Persistence.load(VoiceEnrollment.self, name: "voice.json") {
            while e.slots.count < 10 { e.slots.append(VoiceSlot()) }
            enrollment = e
        }
        VoiceService.shared.onSpeakingChanged = { [weak self] speaking in
            guard let self = self else { return }
            self.ignoreInput = speaking
            if !speaking && self.mode == .listening { self.scheduleRestart() }
        }
    }

    private var commands: [String] { store?.prefs.voiceCommands ?? Preferences.defaultCommands }
    private var ownerGate: Bool { store?.prefs.ownerVoiceGate ?? false }

    // MARK: Permissions
    private func requestPermissions(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { auth in
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    let ok = (auth == .authorized) && granted
                    self.permissionMessage = ok ? nil : "Allow Microphone and Speech Recognition in iPhone Settings → Lo Jaiga."
                    completion(ok)
                }
            }
        }
    }

    // MARK: Listening
    func startListening() {
        requestPermissions { ok in
            guard ok else { return }
            self.stopPipeline()
            self.mode = .listening
            self.status = "Listening for your commands…"
            self.heard = ""
            self.startPipeline()
        }
    }

    func stopListening() {
        stopPipeline()
        mode = .idle
        status = "Voice control is off"
        VoiceService.shared.sessionManagedElsewhere = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startPipeline() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            status = "Speech recognizer is not available right now"
            return
        }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default,
                              options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
            try s.setActive(true)
        } catch {
            status = "Audio error: \(error.localizedDescription)"
            return
        }
        VoiceService.shared.sessionManagedElsewhere = true

        generation += 1
        let gen = generation

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        var hints = commands
        for slot in enrollment.slots { hints += slot.aliases }
        req.contextualStrings = hints
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { status = "No microphone input available"; return }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            if let v = FeatureExtractor.frameVector(buffer) {
                DispatchQueue.main.async { self?.ingest(v) }
            }
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            status = "Couldn't start the microphone: \(error.localizedDescription)"
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            DispatchQueue.main.async {
                guard let self = self, gen == self.generation else { return }
                self.handle(text: text, ended: isFinal || failed)
            }
        }
    }

    private func stopPipeline() {
        generation += 1
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        frames.removeAll()
    }

    private func scheduleRestart() {
        guard !restartScheduled else { return }
        restartScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.restartScheduled = false
            guard self.mode == .listening else { return }
            self.stopPipeline()
            self.startPipeline()
        }
    }

    private func ingest(_ v: [Double]) {
        frames.append(v)
        if frames.count > 120 { frames.removeFirst(frames.count - 120) }
    }

    private func handle(text: String?, ended: Bool) {
        if let text = text {
            heard = text
            switch mode {
            case .enrolling: enrollTranscript = text
            case .listening: if !ignoreInput { evaluate(transcript: text) }
            case .idle: break
            }
        }
        if ended && mode == .listening { scheduleRestart() }   // recognition tasks time out after ~1 min
    }

    private func evaluate(transcript: String) {
        guard Date().timeIntervalSince(lastFire) > 1.2 else { return }
        let cmds = commands
        guard let m = VoiceMatcher.best(transcript: transcript, commands: cmds,
                                        aliases: enrollment.slots.map { $0.aliases }) else { return }

        if ownerGate && !enrollment.ownerProfile.isEmpty {
            let recent = Array(frames.suffix(40))
            let sim = recent.isEmpty ? 0 : FeatureExtractor.cosine(FeatureExtractor.mean(recent), enrollment.ownerProfile)
            if sim < enrollment.threshold {
                status = String(format: "Ignored — voice didn't match (%.2f < %.2f)", sim, enrollment.threshold)
                lastFire = Date()
                scheduleRestart()
                return
            }
        }
        lastFire = Date()
        lastAction = "“\(cmds[m.index])”"
        status = "Heard: \(cmds[m.index])"
        onCommand?(m.index)
        scheduleRestart()   // clears the transcript so the same words don't fire twice
    }

    // MARK: Enrollment
    func recordEnrollment(slot: Int) {
        guard slot >= 0, slot < 10 else { return }
        requestPermissions { ok in
            guard ok else { return }
            self.stopPipeline()
            self.enrollTranscript = ""
            self.heard = ""
            self.mode = .enrolling(slot)
            self.status = "Say “\(self.commands[slot])” now…"
            self.startPipeline()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { self.finishEnrollment(slot: slot) }
        }
    }

    private func finishEnrollment(slot: Int) {
        guard case .enrolling(let current) = mode, current == slot else { return }
        let captured = frames
        let transcript = enrollTranscript
        stopPipeline()
        mode = .idle
        VoiceService.shared.sessionManagedElsewhere = false
        guard captured.count >= 6 else {
            status = "I couldn't hear you clearly. Move closer to the microphone and try again."
            return
        }
        var s = enrollment.slots[slot]
        s.profile = FeatureExtractor.mean(captured)
        s.takes += 1
        let norm = VoiceMatcher.normalize(transcript)
        if !norm.isEmpty && norm != VoiceMatcher.normalize(commands[slot]) && !s.aliases.contains(norm) {
            s.aliases.append(norm)
            if s.aliases.count > 4 { s.aliases.removeFirst() }
        }
        enrollment.slots[slot] = s
        recomputeOwnerProfile()
        status = norm.isEmpty ? "Saved voice sample" : "Saved. I heard: “\(norm)”"
    }

    private func recomputeOwnerProfile() {
        let profiles = enrollment.slots.compactMap { $0.profile }
        guard !profiles.isEmpty else { enrollment.ownerProfile = []; persist(); return }
        let owner = FeatureExtractor.mean(profiles)
        enrollment.ownerProfile = owner
        if profiles.count >= 3 {
            let low = profiles.map { FeatureExtractor.cosine($0, owner) }.min() ?? 0.8
            enrollment.threshold = max(0.35, low - 0.10)
        } else {
            enrollment.threshold = 0.6
        }
        if enrollment.completed { enrollment.enrolledAt = Date() }
        persist()
    }

    func deleteVoiceData() {
        enrollment = VoiceEnrollment()
        Persistence.delete(name: "voice.json")
        status = "Voice data deleted"
        store?.prefs.ownerVoiceGate = false
    }

    private func persist() { Persistence.save(enrollment, name: "voice.json") }
}
