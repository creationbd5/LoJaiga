import SwiftUI

struct VoiceView: View {
    @EnvironmentObject var store: TripStore
    @EnvironmentObject var voice: VoiceCommandEngine

    private var listening: Bool { voice.mode == .listening }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Listen for commands", isOn: Binding(
                        get: { listening },
                        set: { on in if on { voice.startListening() } else { voice.stopListening() } }))
                    Text(voice.status).font(.footnote).foregroundStyle(LJ.secondary)
                    if !voice.heard.isEmpty { Text("Heard: “\(voice.heard)”").font(.footnote) }
                    if let msg = voice.permissionMessage { Text(msg).font(.footnote).foregroundStyle(LJ.coral) }
                    Toggle("Read offer verdicts aloud", isOn: $store.prefs.voiceEnabled)
                    Picker("Speech language", selection: $store.prefs.voiceLanguage) {
                        Text("English").tag("en-US")
                        Text("Bangla").tag("bn-BD")
                    }
                }
                .listRowBackground(LJ.panel)

                Section("Owner voice enrollment (experimental)") {
                    ProgressView(value: Double(voice.enrollment.enrolledCount), total: 10) {
                        Text("\(voice.enrollment.enrolledCount) of 10 commands recorded").font(.footnote)
                    }
                    .tint(LJ.teal)
                    ForEach(0..<10, id: \.self) { i in slotRow(i) }
                    Toggle("Only obey my enrolled voice", isOn: Binding(
                        get: { store.prefs.ownerVoiceGate },
                        set: { store.prefs.ownerVoiceGate = $0 }))
                        .disabled(!voice.enrollment.completed)
                    Button("Delete my voice data", role: .destructive) { voice.deleteVoiceData() }
                }
                .listRowBackground(LJ.panel)

                Section("Read this") {
                    Text("Commands only control Lo Jaiga (read the verdict, open Maps, log skipped). They cannot accept, decline or tap anything in Uber.")
                    Text("Owner-voice matching is a crude spectral comparison. It is NOT a secure voiceprint, can be fooled by a recording or a similar voice, and has had no independent testing. Treat it as a convenience filter only.")
                    Text("iOS has no always-on wake word for third-party apps. Listening runs only after you turn it on; it may continue with the screen on while Maps is in front, but iOS can stop it at any time. The microphone indicator stays visible.")
                    Text("Only voice features and the words the recognizer heard are saved, on this phone. No raw audio is kept.")
                }
                .font(.footnote).foregroundStyle(LJ.secondary)
                .listRowBackground(LJ.panel)
            }
            .scrollContentBackground(.hidden)
            .background(LJ.bg)
            .navigationTitle("Voice")
        }
    }

    private func slotRow(_ i: Int) -> some View {
        let slot = voice.enrollment.slots[i]
        let recording = voice.mode == .enrolling(i)
        return HStack(spacing: 10) {
            Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(LJ.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Command", text: $store.prefs.voiceCommands[i])
                if let h = slot.aliases.last {
                    Text("Heard as: “\(h)”").font(.caption2).foregroundStyle(LJ.secondary)
                }
            }
            Spacer()
            if slot.profile != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(LJ.mint) }
            Button(recording ? "Listening…" : (slot.profile == nil ? "Record" : "Redo")) {
                voice.recordEnrollment(slot: i)
            }
            .buttonStyle(.bordered).tint(LJ.teal)
            .disabled(voice.mode == .enrolling(i) || (voice.mode != .idle && voice.mode != .listening))
        }
    }
}
