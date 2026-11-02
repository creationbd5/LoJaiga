import SwiftUI
import PhotosUI

struct OfferView: View {
    @EnvironmentObject var store: TripStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var ocrNote: String?
    @State private var toast: String?

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
                    store.log(.taken); toast = "Logged as taken. Accept it inside Uber Driver."
                } label: { Label("Log: I took it", systemImage: "checkmark").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(LJ.gold).foregroundStyle(LJ.bg)
                Button {
                    store.log(.skipped); toast = "Logged as skipped."
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
            Button("Clear offer", role: .destructive) { store.current = TripOffer(); ocrNote = nil }
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
        let parsed = OfferOCR.parse(lines: await OfferOCR.recognizeLines(in: img))
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
}
