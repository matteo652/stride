import SwiftUI
import MapKit
import UIKit

struct RunView: View {
    @EnvironmentObject var tracker: RunTracker
    @EnvironmentObject var store: RunStore
    @EnvironmentObject var settings: SettingsStore

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var finishedRun: RunRecord?
    @State private var confirmStop = false
    @State private var showTooShort = false

    var body: some View {
        VStack(spacing: 0) {
            mapSection
            statsSection
            controls
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(item: $finishedRun) { run in
            NavigationStack {
                RunDetailView(run: run)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { finishedRun = nil }
                        }
                    }
            }
        }
        .alert("Run too short", isPresented: $showTooShort) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Not enough GPS distance was recorded, so this run was not saved.")
        }
        .onAppear {
            tracker.settings = settings
            if tracker.authorization == .notDetermined {
                tracker.requestPermission()
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Map(position: $camera) {
            UserAnnotation()
            if tracker.coordinates.count > 1 {
                MapPolyline(coordinates: tracker.coordinates)
                    .stroke(Color.ember, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .frame(height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .topLeading) {
            if let acc = tracker.gpsAccuracy {
                HStack(spacing: 5) {
                    Circle()
                        .fill(acc < 12 ? Color.green : (acc < 25 ? Color.yellow : Color.red))
                        .frame(width: 8, height: 8)
                    Text("GPS")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(Format.clock(tracker.elapsed))
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(stateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stateColor)
                    .textCase(.uppercase)
            }
            .padding(.top, 12)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatTile(label: "Distance",
                         value: Format.distance(tracker.distance, units: settings.units),
                         unit: settings.units.distanceSymbol)
                StatTile(label: "Pace",
                         value: Format.pace(metersPerSecond: tracker.currentSpeed, units: settings.units),
                         unit: settings.units.paceSymbol)
                StatTile(label: "Avg pace",
                         value: avgPaceText,
                         unit: settings.units.paceSymbol)
                StatTile(label: "Elev gain",
                         value: String(format: "%.0f", tracker.elevationGain),
                         unit: "m")
                StatTile(label: "Cadence",
                         value: cadenceText,
                         unit: "spm")
                StatTile(label: "Calories",
                         value: String(format: "%.0f", liveCalories),
                         unit: "kcal")
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
    }

    private var avgPaceText: String {
        guard tracker.distance > 30, tracker.elapsed > 0 else { return "--:--" }
        return Format.pace(secondsPerUnit: tracker.elapsed / (tracker.distance / settings.units.unitFactor))
    }

    private var cadenceText: String {
        if let c = tracker.cadence { return String(format: "%.0f", c) }
        return "--"
    }

    private var liveCalories: Double {
        1.036 * settings.weightKg * (tracker.distance / 1000)
    }

    private var stateLabel: String {
        switch tracker.state {
        case .idle: return "Ready"
        case .running: return "Recording"
        case .paused: return "Paused"
        case .autoPaused: return "Auto-paused"
        }
    }

    private var stateColor: Color {
        switch tracker.state {
        case .running: return Color.ember
        case .idle: return Color.secondary
        default: return Color.amber
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 14) {
            switch tracker.state {
            case .idle:
                Button {
                    startTapped()
                } label: {
                    Label("Start run", systemImage: "figure.run")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .background(Color.ember, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(Color.ink)
            default:
                Button {
                    tracker.togglePause()
                } label: {
                    Image(systemName: tracker.state == .running ? "pause.fill" : "play.fill")
                        .font(.title.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)

                Button {
                    confirmStop = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .background(Color.ember, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(Color.ink)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .confirmationDialog("Finish this run?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Finish & save", role: .destructive) { finish() }
            Button("Keep running", role: .cancel) { }
        }
    }

    private func startTapped() {
        switch tracker.authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            camera = .userLocation(fallback: .automatic)
            tracker.start()
        case .notDetermined:
            tracker.requestPermission()
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func finish() {
        if let rec = tracker.stop() {
            store.add(rec)
            finishedRun = rec
        } else {
            showTooShort = true
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
