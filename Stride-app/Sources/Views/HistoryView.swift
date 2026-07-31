import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: RunStore
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Group {
                if store.runs.isEmpty {
                    ContentUnavailableView(
                        "No runs yet",
                        systemImage: "figure.run",
                        description: Text("Head to the Run tab and record your first one.")
                    )
                } else {
                    List {
                        Section {
                            weekSummary
                                .listRowBackground(Color.card)
                        }
                        Section {
                            ForEach(store.runs) { run in
                                NavigationLink {
                                    RunDetailView(run: run)
                                } label: {
                                    RunRow(run: run)
                                }
                                .listRowBackground(Color.card)
                            }
                            .onDelete { offsets in
                                let toDelete = offsets.map { store.runs[$0] }
                                for run in toDelete { store.delete(run) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("History")
        }
    }

    private var weekSummary: some View {
        let week = store.runs(inLastDays: 7)
        let dist = week.reduce(0.0) { $0 + $1.distance }
        let dur = week.reduce(0.0) { $0 + $1.duration }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LAST 7 DAYS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(Format.distance(dist, units: settings.units)) \(settings.units.distanceSymbol)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(week.count) runs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(Format.clock(dur))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

struct RunRow: View {
    @EnvironmentObject var settings: SettingsStore
    let run: RunRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundStyle(Color.ember)
                .frame(width: 40, height: 40)
                .background(Color.appBackground, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(run.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let dist = Format.distance(run.distance, units: settings.units)
        let pace = run.distance > 0
            ? Format.pace(secondsPerUnit: run.duration / (run.distance / settings.units.unitFactor))
            : "--:--"
        return "\(dist) \(settings.units.distanceSymbol) · \(Format.clock(run.duration)) · \(pace)\(settings.units.paceSymbol)"
    }
}
