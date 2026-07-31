import Foundation
import CoreLocation

final class RunStore: ObservableObject {
    @Published private(set) var runs: [RunRecord] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("runs.json")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([RunRecord].self, from: data) {
            runs = decoded.sorted { $0.date > $1.date }
        }
    }

    func add(_ run: RunRecord) {
        runs.insert(run, at: 0)
        save()
    }

    func delete(_ run: RunRecord) {
        runs.removeAll { $0.id == run.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(runs) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Aggregates

    func runs(inLastDays days: Int) -> [RunRecord] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        return runs.filter { $0.date >= cutoff }
    }

    var longestRun: RunRecord? {
        runs.max { $0.distance < $1.distance }
    }

    var fastestPaceRun: RunRecord? {
        runs.filter { $0.distance >= 1000 && $0.duration > 0 }
            .min { ($0.duration / $0.distance) < ($1.duration / $1.distance) }
    }

    var biggestClimb: RunRecord? {
        runs.max { $0.elevationGain < $1.elevationGain }
    }

    /// Fastest continuous effort over `target` meters found inside any run
    /// (sliding window over recorded points, using moving time).
    func bestEffort(target: Double) -> TimeInterval? {
        var best: TimeInterval? = nil
        for run in runs where run.distance >= target {
            guard run.points.count > 2 else { continue }
            var cum: [Double] = [0]
            cum.reserveCapacity(run.points.count)
            for i in 1..<run.points.count {
                let a = CLLocation(latitude: run.points[i - 1].lat, longitude: run.points[i - 1].lon)
                let b = CLLocation(latitude: run.points[i].lat, longitude: run.points[i].lon)
                cum.append(cum[i - 1] + b.distance(from: a))
            }
            var j = 0
            for i in 0..<run.points.count {
                while j < run.points.count && cum[j] - cum[i] < target { j += 1 }
                if j >= run.points.count { break }
                let time = run.points[j].t - run.points[i].t
                if time > 0, best == nil || time < best! {
                    best = time
                }
            }
        }
        return best
    }
}
