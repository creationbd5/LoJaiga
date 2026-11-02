import SwiftUI
import PhotosUI

struct OfferView: View {
    @EnvironmentObject var store: TripStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var ocrNote: String?
    @State private var toast: String?
    @State private var rawOCR: [String] = []
    @State private var lastParsed = ParsedOffer()
    @State private var showOCRDetails = false

    private var result: Evaluation { store.evaluate(store.current) }

    private func tint(_ r: Evaluation) -> Color {
        switch r.verdict {
        case .good: return LJ.mint
        case .bad: return LJ.coral
        case .incomplete: return LJ.secondary
        }
    }
    private func title(_ r: Evaluation) -> String {
        switch r.verdict {
        case .good: return "GOOD OFFER"
        case .bad: return "BAD OFFER"
        case .incomplete: return "ENTER OFFER"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    verdictCard
                    inputsCard
                    actionsCard
                    ocrDiagnosticsCard
                    Text("Lo Jaiga does not read or tap the Uber app. Accept or decline inside Uber Driver yourself, and never use this screen while driving.")
                        .font(.footnote).foregroundStyle(LJ.secondary).padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(LJ.bg)
            .navigationTitle("Analyze Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .alert(toast ?? "", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: Verdict
    private var verdictCard: some View {
        let r = result
        let o = store.current
        return Surface {
            HStack(spacing: 16) {
                MatchRing(score: r.score, color: tint(r))
                VStack(alignment: .leading, spacing: 6) {
                    Chip(text: title(r), color: tint(r))
                    Text(o.fare, format: .currency(code: LJ.currency))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if r.verdict != .incomplete {
                        Text("\(o.perKm.formatted(.number.precision(.fractionLength(2)))) /km  •  \(o.perHour.formatted(.number.precision(.fractionLength(0)))) /hr")
                            .font(.subheadline).foregroundStyle(LJ.teal)
                        Text("Est. net \(r.estimatedNet.formatted(.currency(code: LJ.currency))) (\(r.netPerHour.formatted(.number.precision(.fractionLength(0))))/hr)")
                            .font(.footnote).foregroundStyle(LJ.secondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(r.problems, id: \.self) { p in
                    Label(p, systemImage: "xmark.circle.fill").foregroundStyle(LJ.coral).font(.subheadline)
                }
                ForEach(r.goods, id: \.self) { g in
                    Label(g, systemImage: "checkmark.circle.fill").foregroundStyle(LJ.mint).font(.subheadline)
                }
                ForEach(r.notes, id: \.self) { n in
                    Label(n, systemImage: "info.circle").foregroundStyle(LJ.secondary).font(.footnote)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Inputs
    private var inputsCard: some View {
        Surface {
            HStack {
                Text("Offer details").font(.headline)
                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("From screenshot (beta)", systemImage: "text.viewfinder").font(.footnote.weight(.semibold))
                }
                .onChange(of: pickerItem) { _, newItem in
                    guard let newItem = newItem else { return }
                    Task { await importScreenshot(newItem) }
                }
            }
            Button {
                var sample = TripOffer()
                sample.fare = 28.50
                sample.pickupKm = 3.2
                sample.pickupMinutes = 8
                sample.rideKm = 11.8
                sample.rideMinutes = 24
                sample.destination = "Scarborough Town Centre"
                store.current = sample
                ocrNote = "Sample loaded. This is demonstration data, not a real Uber offer."
                rawOCR = ["SAMPLE ONLY", "$28.50", "8 min (3.2 km) away", "24 min (11.8 km) trip", "Scarborough Town Centre"]
                showOCRDetails = true
            } label: {
                Label("Load sample offer for testing", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered).tint(LJ.teal)
            if let note = ocrNote {
                Text(note).font(.footnote).foregroundStyle(LJ.gold)
            }
            NumberRow(title: "Fare (CAD)", value: $store.current.fare)
            NumberRow(title: "Pickup km", value: $store.current.pickupKm)
            NumberRow(title: "Pickup minutes", value: $store.current.pickupMinutes)
            NumberRow(title: "Trip km", value: $store.current.rideKm)
            NumberRow(title: "Trip minutes", value: $store.current.rideMinutes)
            Divider()
            TextField("Drop-off area (e.g. Scarborough Town Centre)", text: $store.current.destination)
            if let name = store.current.resolvedName {
                Label("Located: \(name)", systemImage: "mappin.circle.fill").font(.footnote).foregroundStyle(LJ.mint)
            } else if !store.current.destination.trimmingCharacters(in: .whitespaces).isEmpty {
                Label("Not located yet — matching by name only", systemImage: "mappin.slash")
                    .font(.footnote).foregroundStyle(LJ.secondary)
            }
            TextField("Roads on route (optional, e.g. Highway 401)", text: $store.current.routeDescription)
        }
        .task(id: store.current.destination) { await geocodeDestination() }
    }

    // MARK: Actions
    private var actionsCard: some View {
        Surface {
            HStack(spacing: 10) {
                Button {
                    if result.verdict != .incomplete {
                        store.log(.taken); store.flush()
                        toast = "Saved to History as taken. This does not accept an Uber trip."
                    } else { toast = "Complete the offer details before logging." }
                } label: { Label("Log: I took it", systemImage: "checkmark").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(LJ.gold).foregroundStyle(LJ.bg)
                Button {
                    if result.verdict != .incomplete {
                        store.log(.skipped); store.flush(); toast = "Saved to History as skipped."
                    } else { toast = "Complete the offer details before logging." }
                } label: { Label("Log: Skipped", systemImage: "xmark").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).tint(LJ.coral)
            }
            HStack(spacing: 10) {
                Button {
                    guard store.prefs.voiceEnabled else { return }
                    VoiceService.shared.say(OfferSpeech.summary(store.current, result), language: store.prefs.voiceLanguage)
                } label: { Label("Read aloud", systemImage: "speaker.wave.2").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).tint(LJ.teal)
                Button {
                    let o = store.current
                    MapLauncher.open(name: o.destination, lat: o.destLat, lon: o.destLon,
                                     provider: store.prefs.mapApp, avoidTolls: store.prefs.avoidTolls)
                } label: { Label("Navigate", systemImage: "location.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).tint(LJ.teal)
                    .disabled(store.current.destination.isEmpty && !store.current.hasCoordinate)
            }
            Button("Clear offer", role: .destructive) { store.current = TripOffer(); ocrNote = nil; rawOCR = []; lastParsed = ParsedOffer() }
                .font(.footnote)
        }
    }

    // MARK: Helpers
    @MainActor
    private func geocodeDestination() async {
        let dest = store.current.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        store.current.resolvedName = nil
        store.current.destLat = nil
        store.current.destLon = nil
        guard dest.count >= 3 else { return }
        try? await Task.sleep(nanoseconds: 800_000_000)   // debounce typing
        guard !Task.isCancelled else { return }
        if let m = await GeoService.search(dest), !Task.isCancelled {
            store.current.resolvedName = m.name
            store.current.destLat = m.lat
            store.current.destLon = m.lon
        }
    }

    @MainActor
    private func importScreenshot(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else {
            ocrNote = "Couldn't open that image."
            return
        }
        let lines = await OfferOCR.recognizeLines(in: img)
        rawOCR = lines
        let parsed = OfferOCR.parse(lines: lines)
        lastParsed = parsed
        showOCRDetails = true
        var filled: [String] = []
        if let v = parsed.fare { store.current.fare = v; filled.append("fare") }
        if let v = parsed.pickupMinutes { store.current.pickupMinutes = v; filled.append("pickup min") }
        if let v = parsed.pickupKm { store.current.pickupKm = v; filled.append("pickup km") }
        if let v = parsed.rideMinutes { store.current.rideMinutes = v; filled.append("trip min") }
        if let v = parsed.rideKm { store.current.rideKm = v; filled.append("trip km") }
        ocrNote = filled.isEmpty
            ? "Couldn't find offer numbers in that screenshot. Enter them manually."
            : "Filled: \(filled.joined(separator: ", ")). Beta reader — check every number."
    }

    private var ocrDiagnosticsCard: some View {
        Surface {
            DisclosureGroup(isExpanded: $showOCRDetails) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Recognized text lines: \(rawOCR.count)")
                        .font(.caption.weight(.bold)).foregroundStyle(LJ.teal)
                    if rawOCR.isEmpty {
                        Text("No screenshot scanned yet. Use From screenshot above.")
                            .font(.footnote).foregroundStyle(LJ.secondary)
                    } else {
                        Text(rawOCR.joined(separator: "\n"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(LJ.secondary)
                            .textSelection(.enabled)
                    }
                    Divider()
                    Text("Parsed: \(lastParsed.foundCount) / 5 values")
                        .font(.subheadline.weight(.semibold))
                    Text("Fare \(diagnostic(lastParsed.fare)) • Pickup \(diagnostic(lastParsed.pickupKm)) km / \(diagnostic(lastParsed.pickupMinutes)) min • Trip \(diagnostic(lastParsed.rideKm)) km / \(diagnostic(lastParsed.rideMinutes)) min")
                        .font(.footnote).foregroundStyle(LJ.secondary)
                    Text("OCR guesses may be wrong. Always verify numbers before saving. No continuous Uber capture is active.")
                        .font(.caption).foregroundStyle(LJ.gold)
                }
                .padding(.top, 10)
            } label: {
                Label("OCR diagnostic report", systemImage: "text.magnifyingglass")
                    .font(.headline).foregroundStyle(LJ.teal)
            }
        }
    }

    private func diagnostic(_ number: Double?) -> String {
        guard let number = number else { return "not found" }
        return number.formatted(.number.precision(.fractionLength(0...2)))
    }

}
