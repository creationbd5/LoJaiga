import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TripStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Profit rules") {
                    NumberRow(title: "Minimum fare (CAD)", value: $store.prefs.minFare)
                    NumberRow(title: "Minimum CAD / km", value: $store.prefs.minPerKm)
                    NumberRow(title: "Minimum CAD / hour", value: $store.prefs.minPerHour)
                    NumberRow(title: "Max pickup minutes", value: $store.prefs.maxPickupMinutes)
                    NumberRow(title: "Vehicle cost CAD / km", value: $store.prefs.operatingCostKm)
                }
                .listRowBackground(LJ.panel)

                Section("Places") {
                    NavigationLink("Home, preferred & avoided areas") { PlacesView() }
                }
                .listRowBackground(LJ.panel)

                Section("Navigation") {
                    Picker("Preferred map", selection: $store.prefs.mapApp) {
                        ForEach(["Google Maps", "Apple Maps", "Waze"], id: \.self) { Text($0) }
                    }
                    Toggle("Prefer avoiding tolls", isOn: $store.prefs.avoidTolls)
                    Text("Only Google Maps honours the toll setting through a link. Apple Maps and Waze ignore it.")
                        .font(.footnote).foregroundStyle(LJ.secondary)
                }
                .listRowBackground(LJ.panel)

                Section("About") {
                    NavigationLink("What works and what doesn't") { CapabilitiesView() }
                }
                .listRowBackground(LJ.panel)
            }
            .scrollContentBackground(.hidden)
            .background(LJ.bg)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
    }
}

struct PlacesView: View {
    @EnvironmentObject var store: TripStore

    var body: some View {
        Form {
            Section("Home (for “Bari Jamu”)") {
                PlaceEditor(place: $store.prefs.home, showRadius: false)
            }
            .listRowBackground(LJ.panel)

            Section("Preferred drop-off areas") {
                Toggle("Accept any destination", isOn: $store.prefs.anyDestination)
                ForEach($store.prefs.preferred) { $p in PlaceEditor(place: $p, showRadius: true) }
                Text("Tap the pin to locate a place on the map. Located places are matched by real distance; others by name only.")
                    .font(.footnote).foregroundStyle(LJ.secondary)
            }
            .listRowBackground(LJ.panel)

            Section("Avoid areas or roads") {
                ForEach($store.prefs.avoid) { $p in PlaceEditor(place: $p, showRadius: true) }
                Text("Road names are also checked against the “roads on route” text you enter on the Analyze tab. Lo Jaiga does not know the real route of an Uber offer.")
                    .font(.footnote).foregroundStyle(LJ.secondary)
            }
            .listRowBackground(LJ.panel)
        }
        .scrollContentBackground(.hidden)
        .background(LJ.bg)
        .navigationTitle("Places")
    }
}

struct PlaceEditor: View {
    @Binding var place: PlaceRule
    var showRadius = true
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Place or road name", text: $place.name)
                Button { Task { await locate() } } label: {
                    if busy { ProgressView() } else { Image(systemName: "mappin.and.ellipse") }
                }
                .buttonStyle(.borderless)
                .disabled(place.isEmpty || busy)
            }
            if let r = place.resolvedName {
                Label(r, systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(LJ.mint)
            } else if failed {
                Text("Couldn't find that place").font(.caption).foregroundStyle(LJ.coral)
            } else if !place.isEmpty {
                Text("Not located — matched by name only").font(.caption).foregroundStyle(LJ.secondary)
            }
            if showRadius {
                HStack {
                    Text("Radius \(Int(place.radiusKm)) km").font(.caption).foregroundStyle(LJ.secondary)
                    Slider(value: $place.radiusKm, in: 1...30, step: 1)
                }
            }
        }
        .onChange(of: place.name) { _, newName in
            if let located = place.locatedFor, located != newName {
                place.lat = nil; place.lon = nil; place.resolvedName = nil; place.locatedFor = nil
            }
            failed = false
        }
    }

    @MainActor
    private func locate() async {
        busy = true
        defer { busy = false }
        if let m = await GeoService.search(place.name) {
            place.lat = m.lat
            place.lon = m.lon
            place.resolvedName = m.name
            place.locatedFor = place.name
            failed = false
        } else {
            failed = true
        }
    }
}

struct CapabilitiesView: View {
    private struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private let works = [
        Item(icon: "checkmark.circle.fill", color: LJ.mint, title: "Good / Bad offer analysis",
             detail: "Scores fare, $/km, $/hour and pickup time from numbers you enter or import from a screenshot."),
        Item(icon: "checkmark.circle.fill", color: LJ.mint, title: "Trip history & CSV export", detail: "Stored on this phone only."),
        Item(icon: "checkmark.circle.fill", color: LJ.mint, title: "Spoken verdicts", detail: "Text-to-speech through the phone speaker or Bluetooth."),
        Item(icon: "checkmark.circle.fill", color: LJ.mint, title: "Open Google Maps / Apple Maps / Waze", detail: "Hands the destination to the map app. Turn-by-turn happens in that app.")
    ]
    private let experimental = [
        Item(icon: "exclamationmark.triangle.fill", color: LJ.gold, title: "Screenshot reader (beta)",
             detail: "Reads text from a screenshot you provide. The Uber layout is not verified; always check the numbers."),
        Item(icon: "exclamationmark.triangle.fill", color: LJ.gold, title: "Voice commands",
             detail: "Work while the app is listening. Accuracy for Banglish words depends on the iPhone recognizer; enrollment teaches it how you say them."),
        Item(icon: "exclamationmark.triangle.fill", color: LJ.gold, title: "Owner-voice filter",
             detail: "Crude comparison, not secure, no replay protection, untested."),
        Item(icon: "exclamationmark.triangle.fill", color: LJ.gold, title: "Radius matching",
             detail: "Accurate only for places you located on the map and a drop-off area that was located too.")
    ]
    private let blocked = [
        Item(icon: "xmark.circle.fill", color: LJ.coral, title: "Auto Accept / Match in Uber",
             detail: "iOS does not let one app tap buttons in another app, and Uber offers no public API for driver offers. Not implemented. Tools that try this have been warned or banned by rideshare companies."),
        Item(icon: "xmark.circle.fill", color: LJ.coral, title: "Live offers, Trip Radar, busy areas, surge",
             detail: "These live only inside Uber's own app. Lo Jaiga has no access to them."),
        Item(icon: "xmark.circle.fill", color: LJ.coral, title: "CarPlay",
             detail: "Needs a CarPlay entitlement from Apple in an approved category. Not enabled; a sideloaded test app cannot use it."),
        Item(icon: "xmark.circle.fill", color: LJ.coral, title: "Always-on “Lo Jaiga” wake word",
             detail: "Not available to third-party apps on iOS.")
    ]

    var body: some View {
        Form {
            group("Works (verify on your phone)", works)
            group("Experimental", experimental)
            group("Not possible / not built", blocked)
        }
        .scrollContentBackground(.hidden)
        .background(LJ.bg)
        .navigationTitle("Capabilities")
    }

    private func group(_ title: String, _ items: [Item]) -> some View {
        Section(title) {
            ForEach(items) { i in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: i.icon).foregroundStyle(i.color).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(i.title).font(.subheadline.weight(.semibold))
                        Text(i.detail).font(.footnote).foregroundStyle(LJ.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listRowBackground(LJ.panel)
    }
}
