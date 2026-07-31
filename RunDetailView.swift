import SwiftUI
import MapKit
import Charts
import CoreLocation

enum RouteGeometry {
    static func boundingRect(of coords: [CLLocationCoordinate2D]) -> MKMapRect {
        guard !coords.isEmpty else { return MKMapRect.world }
        var rect = MKMapRect.null
        for c in coords {
            let p = MKMapPoint(c)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 1, height: 1))
        }
        let dx = max(rect.size.width * 0.25, 500)
        let dy = max(rect.size.height * 0.25, 500)
        return rect.insetBy(dx: -dx, dy: -dy)
    }
}

struct RunDetailView: View {
    @EnvironmentObject var settings: SettingsStore
    let run: RunRecord

    @State private var paceSeries: [DistanceSample] = []
    @State private var elevSeries: [DistanceSample] = []
    @State private var gpxURL: URL?

    private var coords: [CLLocationCoordinate2D] { run.points.map { $0.coordinate } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                routeMap
                statGrid
                if !run.splits.isEmpty { splitsCard }
                if paceSeries.count > 3 { paceChartCard }
                if elevSeries.count > 3 { elevChartCard }
            }
            .padding(12)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(run.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let gpxURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: gpxURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            let s = run.series(units: settings.units)
            paceSeries = s.pace
            elevSeries = s.elevation
            exportGPX()
        }
    }

    private func exportGPX() {
        let name = "stride-run-\(run.id.uuidString.prefix(8)).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if let data = GPX.document(for: run).data(using: .utf8) {
            try? data.write(to: url, options: .atomic)
            gpxURL = url
        }
    }

    // MARK: - Map

    private var routeMap: some View {
        Map(initialPosition: .rect(RouteGeometry.boundingRect(of: coords))) {
            if coords.count > 1 {
                MapPolyline(coordinates: coords)
                    .stroke(Color.ember, lineWidth: 4)
            }
            if let first = coords.first {
                Annotation("Start", coordinate: first) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if coords.count > 1, let last = coords.last {
                Annotation("End", coordinate: last) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Stats

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(label: "Distance",
                     value: Format.distance(run.distance, units: settings.units),
                     unit: settings.units.distanceSymbol)
            StatTile(label: "Moving time",
                     value: Format.clock(run.duration),
                     unit: "h:m:s")
            StatTile(label: "Avg pace",
                     value: avgPace,
                     unit: settings.units.paceSymbol)
            StatTile(label: "Elev gain",
                     value: String(format: "%.0f", run.elevationGain),
                     unit: "m")
            StatTile(label: "Calories",
                     value: String(format: "%.0f", run.calories),
                     unit: "kcal")
            StatTile(label: "Avg speed",
                     value: String(format: "%.1f", run.avgSpeed * settings.units.speedFactor),
                     unit: settings.units.speedSymbol)
            StatTile(label: "Cadence",
                     value: run.avgCadence.map { String(format: "%.0f", $0) } ?? "--",
                     unit: "spm")
            StatTile(label: "Best split",
                     value: bestSplitPace,
                     unit: settings.units.paceSymbol)
            StatTile(label: "GPS points",
                     value: "\(run.points.count)",
                     unit: "fixes")
        }
    }

    private var avgPace: String {
        guard run.distance > 0 else { return "--:--" }
        return Format.pace(secondsPerUnit: run.duration / (run.distance / settings.units.unitFactor))
    }

    private var bestSplitPace: String {
        let full = run.splits.filter { $0.distance >= settings.units.unitFactor * 0.98 }
        guard let best = full.min(by: { $0.duration < $1.duration }) else { return "--:--" }
        return Format.pace(secondsPerUnit: best.duration / (best.distance / settings.units.unitFactor))
    }

    // MARK: - Splits

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Splits")
                .font(.headline)
            Chart(run.splits) { s in
                BarMark(
                    x: .value("Pace", splitPaceMinutes(s)),
                    y: .value("Split", "\(s.index)")
                )
                .foregroundStyle(Color.ember)
                .cornerRadius(4)
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(run.splits.count) * 26 + 12)

            ForEach(run.splits) { s in
                HStack {
                    Text("\(settings.units.distanceSymbol.uppercased()) \(s.index)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .leading)
                    Text(String(format: "%.2f", s.distance / settings.units.unitFactor))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text(Format.clock(s.duration))
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                    Text(splitPaceText(s) + settings.units.paceSymbol)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func splitPaceMinutes(_ s: Split) -> Double {
        guard s.distance > 0 else { return 0 }
        return (s.duration / (s.distance / settings.units.unitFactor)) / 60
    }

    private func splitPaceText(_ s: Split) -> String {
        guard s.distance > 0 else { return "--:--" }
        return Format.pace(secondsPerUnit: s.duration / (s.distance / settings.units.unitFactor))
    }

    // MARK: - Charts

    private var paceChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pace · min\(settings.units.paceSymbol)")
                .font(.headline)
            Chart(paceSeries) { p in
                LineMark(
                    x: .value("Distance", p.x),
                    y: .value("Pace", p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.ember)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 170)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var elevChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Elevation · m")
                .font(.headline)
            Chart(elevSeries) { p in
                AreaMark(
                    x: .value("Distance", p.x),
                    y: .value("Elevation", p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.amber.opacity(0.45), Color.amber.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Distance", p.x),
                    y: .value("Elevation", p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.amber)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 150)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
