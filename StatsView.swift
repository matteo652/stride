import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: RunStore
    @EnvironmentObject var settings: SettingsStore

    @State private var best1k: TimeInterval?
    @State private var best5k: TimeInterval?
    @State private var best10k: TimeInterval?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    totalsCard(title: "All time", runs: store.runs)
                    totalsCard(title: "Last 7 days", runs: store.runs(inLastDays: 7))
                    totalsCard(title: "Last 30 days", runs: store.runs(inLastDays: 30))
                    recordsCard
                }
                .padding(12)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Stats")
            .onAppear { computeRecords() }
            .onChange(of: store.runs.count) { computeRecords() }
        }
    }

    private func computeRecords() {
        best1k = store.bestEffort(target: 1000)
        best5k = store.bestEffort(target: 5000)
        best10k = store.bestEffort(target: 10000)
    }

    // MARK: - Cards

    private func totalsCard(title: String, runs: [RunRecord]) -> some View {
        let dist = runs.reduce(0.0) { $0 + $1.distance }
        let dur = runs.reduce(0.0) { $0 + $1.duration }
        let elev = runs.reduce(0.0) { $0 + $1.elevationGain }
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            HStack(spacing: 8) {
                MiniStat(value: "\(runs.count)", label: "runs")
                MiniStat(value: Format.distance(dist, units: settings.units), label: settings.units.distanceSymbol)
                MiniStat(value: Format.clock(dur), label: "time")
                MiniStat(value: String(format: "%.0f", elev), label: "m climb")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal records")
                .font(.headline)
            RecordRow(icon: "arrow.left.and.right",
                      title: "Longest run",
                      value: store.longestRun.map {
                          Format.distance($0.distance, units: settings.units) + " " + settings.units.distanceSymbol
                      } ?? "--")
            RecordRow(icon: "hare.fill",
                      title: "Fastest avg pace",
                      value: store.fastestPaceRun.map {
                          Format.pace(secondsPerUnit: $0.duration / ($0.distance / settings.units.unitFactor)) + settings.units.paceSymbol
                      } ?? "--")
            RecordRow(icon: "mountain.2.fill",
                      title: "Biggest climb",
                      value: store.biggestClimb.map { String(format: "%.0f m", $0.elevationGain) } ?? "--")
            RecordRow(icon: "1.circle.fill",
                      title: "Best 1 km effort",
                      value: best1k.map(Format.clock) ?? "--")
            RecordRow(icon: "5.circle.fill",
                      title: "Best 5 km effort",
                      value: best5k.map(Format.clock) ?? "--")
            RecordRow(icon: "10.circle.fill",
                      title: "Best 10 km effort",
                      value: best10k.map(Format.clock) ?? "--")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct MiniStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecordRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.amber)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
    }
}
