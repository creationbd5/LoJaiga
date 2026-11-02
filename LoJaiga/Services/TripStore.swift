import Foundation
import Combine

final class TripStore: ObservableObject {
    struct Stats { var count = 0; var fare = 0.0; var net = 0.0 }

    @Published var prefs = Preferences()
    @Published var trips: [TripOffer] = []
    /// The offer currently loaded in the Analyzer. Voice commands act on this.
    @Published var current = TripOffer()

    private var bag = Set<AnyCancellable>()

    init() {
        if let p = Persistence.load(Preferences.self, name: "prefs.json") { prefs = p }
        if let t = Persistence.load([TripOffer].self, name: "trips.json") { trips = t }

        // Debounced saves: typing in a text field no longer rewrites everything on every keystroke.
        $prefs.dropFirst()
            .debounce(for: .seconds(0.6), scheduler: DispatchQueue.main)
            .sink { Persistence.save($0, name: "prefs.json") }
            .store(in: &bag)
        $trips.dropFirst()
            .debounce(for: .seconds(0.6), scheduler: DispatchQueue.main)
            .sink { Persistence.save($0, name: "trips.json") }
            .store(in: &bag)
    }

    func flush() {
        Persistence.save(prefs, name: "prefs.json")
        Persistence.save(trips, name: "trips.json")
    }

    func evaluate(_ offer: TripOffer) -> Evaluation {
        OfferEvaluator.evaluate(offer, prefs: prefs)
    }

    /// Records the current offer in the local log. This does NOT touch the Uber app.
    func log(_ status: TripStatus) {
        let e = evaluate(current)
        guard e.verdict != .incomplete else { return }
        var rec = current
        rec.id = UUID()
        rec.createdAt = Date()
        rec.status = status
        rec.score = e.score
        rec.wasGood = (e.verdict == .good)
        trips.insert(rec, at: 0)
    }

    func setStatus(_ id: UUID, _ status: TripStatus) {
        if let i = trips.firstIndex(where: { $0.id == id }) { trips[i].status = status }
    }

    func stats(since start: Date) -> Stats {
        var s = Stats()
        for t in trips where t.createdAt >= start && t.status.countsAsEarning {
            s.count += 1
            s.fare += t.fare
            s.net += t.fare - t.totalKm * prefs.operatingCostKm
        }
        return s
    }

    var csv: String {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let iso = ISO8601DateFormatter()
        var out = "date,status,fare,total_km,total_min,per_km,per_hour,score,destination\n"
        for t in trips {
            out += [iso.string(from: t.createdAt), t.status.label, String(format: "%.2f", t.fare),
                    String(format: "%.1f", t.totalKm), String(format: "%.0f", t.totalMinutes),
                    String(format: "%.2f", t.perKm), String(format: "%.2f", t.perHour),
                    t.score.map(String.init) ?? "", q(t.destination)].joined(separator: ",") + "\n"
        }
        return out
    }
}
