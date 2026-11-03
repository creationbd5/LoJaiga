import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: TripStore
    @State private var filter = 0
    private let filters = ["All", "Taken", "Skipped", "Reviewed"]

    private var filtered: [TripOffer] {
        switch filter {
        case 1: return store.trips.filter { $0.status.countsAsEarning }
        case 2: return store.trips.filter { $0.status == .skipped }
        case 3: return store.trips.filter { $0.status == .reviewed }
        default: return store.trips
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        summary("Today", store.stats(since: Calendar.current.startOfDay(for: Date())))
                        summary("7 days", store.stats(since: Date().addingTimeInterval(-7 * 86_400)))
                        summary("All", store.stats(since: .distantPast))
                    }
                    Picker("Filter", selection: $filter) {
                        ForEach(0..<filters.count, id: \.self) { Text(filters[$0]).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(LJ.panel)

                if filtered.isEmpty {
                    ContentUnavailableView("No trips here", systemImage: "car.side",
                                           description: Text("Log offers from the Analyze tab."))
                        .listRowBackground(Color.clear)
                }

                ForEach(filtered) { t in
                    row(t)
                        .listRowBackground(LJ.panel)
                        .contextMenu {
                            Button { MapLauncher.open(name: t.destination, lat: t.destLat, lon: t.destLon,
                                                      provider: store.prefs.mapApp, avoidTolls: store.prefs.avoidTolls) } label: {
                                Label("Navigate", systemImage: "location")
                            }
                            Button { store.setStatus(t.id, .completed) } label: {
                                Label("Mark completed", systemImage: "checkmark.circle")
                            }
                            Button { store.setStatus(t.id, .taken) } label: {
                                Label("Mark taken", systemImage: "car")
                            }
                        }
                }
                .onDelete { offsets in
                    let ids = offsets.map { filtered[$0].id }
                    store.trips.removeAll { ids.contains($0.id) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LJ.bg)
            .navigationTitle("Trip History")
            .toolbar {
                if !store.trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: store.csv, preview: SharePreview("Lo Jaiga trips.csv")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func summary(_ title: String, _ s: TripStore.Stats) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(LJ.secondary)
            Text(s.fare, format: .currency(code: LJ.currency)).font(.headline).foregroundStyle(LJ.mint)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text("\(s.count) trips").font(.caption2).foregroundStyle(LJ.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ t: TripOffer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.destination.isEmpty ? "No destination" : t.destination).font(.headline)
                Spacer()
                Text(t.fare, format: .currency(code: LJ.currency)).font(.headline).foregroundStyle(LJ.mint)
            }
            HStack(spacing: 8) {
                Text(t.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption).foregroundStyle(LJ.secondary)
                Chip(text: t.status.label, color: t.status.countsAsEarning ? LJ.mint : (t.status == .skipped ? LJ.coral : LJ.secondary))
                if let s = t.score { Chip(text: "Score \(s)", color: LJ.teal) }
            }
            Text("\(t.totalKm.formatted(.number.precision(.fractionLength(1)))) km â€¢ \(Int(t.totalMinutes)) min â€¢ \(t.perHour.formatted(.number.precision(.fractionLength(0))))/hr")
                .font(.subheadline).foregroundStyle(LJ.secondary)
        }
        .padding(.vertical, 4)
    }
}
