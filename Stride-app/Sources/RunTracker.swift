import Foundation
import CoreLocation
import CoreMotion
import UIKit

enum RunState {
    case idle, running, paused, autoPaused
}

final class RunTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published live state

    @Published var state: RunState = .idle
    @Published var authorization: CLAuthorizationStatus = .notDetermined

    @Published var elapsed: TimeInterval = 0            // moving time
    @Published var distance: Double = 0                 // meters
    @Published var currentSpeed: Double = 0             // m/s, smoothed
    @Published var elevationGain: Double = 0            // meters
    @Published var cadence: Double? = nil               // steps per minute
    @Published var coordinates: [CLLocationCoordinate2D] = []
    @Published var splits: [Split] = []
    @Published var gpsAccuracy: Double? = nil           // horizontal accuracy, meters

    var settings: SettingsStore?

    // MARK: - Private

    private let manager = CLLocationManager()
    private let pedometer = CMPedometer()
    private var timer: Timer?

    private var points: [RoutePoint] = []
    private var lastLocation: CLLocation?
    private var lastAltitude: Double?
    private var accumulated: TimeInterval = 0
    private var segmentStart: Date?
    private var startDate: Date?
    private var lastSplitDistance: Double = 0
    private var lastSplitTime: TimeInterval = 0
    private var stillCount = 0
    private var recentSpeeds: [Double] = []
    private var cadenceSum: Double = 0
    private var cadenceCount: Int = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient GPS errors are ignored; tracking continues with the next fix.
    }

    // MARK: - Session control

    func start() {
        guard state == .idle else { return }
        resetMetrics()
        startDate = Date()
        segmentStart = Date()
        state = .running
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        startPedometer()
        startTimer()
        UIApplication.shared.isIdleTimerDisabled = true
        haptic(.success)
    }

    func togglePause() {
        switch state {
        case .running:
            pauseNow(auto: false)
        case .paused, .autoPaused:
            resume()
        default:
            break
        }
    }

    private func pauseNow(auto: Bool) {
        guard state == .running else { return }
        if let s = segmentStart { accumulated += Date().timeIntervalSince(s) }
        segmentStart = nil
        elapsed = accumulated
        state = auto ? .autoPaused : .paused
        if !auto { haptic(.warning) }
    }

    private func resume() {
        guard state == .paused || state == .autoPaused else { return }
        segmentStart = Date()
        state = .running
    }

    /// Ends the session. Returns a record if enough distance was covered, otherwise nil.
    func stop() -> RunRecord? {
        guard state != .idle else { return nil }
        if state == .running, let s = segmentStart {
            accumulated += Date().timeIntervalSince(s)
        }
        segmentStart = nil
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        pedometer.stopUpdates()
        UIApplication.shared.isIdleTimerDisabled = false

        let total = accumulated
        elapsed = total

        // Close the final partial split
        let partial = distance - lastSplitDistance
        if partial > 25 {
            splits.append(Split(index: splits.count + 1, duration: total - lastSplitTime, distance: partial))
        }

        var record: RunRecord? = nil
        if distance >= 50, let start = startDate {
            let weight = settings?.weightKg ?? 70
            let kcal = 1.036 * weight * (distance / 1000)
            let avgCad: Double? = cadenceCount > 0 ? cadenceSum / Double(cadenceCount) : nil
            record = RunRecord(
                date: start,
                duration: total,
                distance: distance,
                elevationGain: elevationGain,
                calories: kcal,
                avgCadence: avgCad,
                points: points,
                splits: splits
            )
        }
        state = .idle
        haptic(.success)
        return record
    }

    private func resetMetrics() {
        elapsed = 0
        distance = 0
        currentSpeed = 0
        elevationGain = 0
        cadence = nil
        coordinates = []
        splits = []
        points = []
        lastLocation = nil
        lastAltitude = nil
        accumulated = 0
        segmentStart = nil
        startDate = nil
        lastSplitDistance = 0
        lastSplitTime = 0
        stillCount = 0
        recentSpeeds = []
        cadenceSum = 0
        cadenceCount = 0
        gpsAccuracy = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard state == .running, let s = segmentStart else { return }
        elapsed = accumulated + Date().timeIntervalSince(s)
    }

    // MARK: - Location processing

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            process(loc)
        }
    }

    private func process(_ loc: CLLocation) {
        gpsAccuracy = loc.horizontalAccuracy

        // Quality gate: reject stale or inaccurate fixes
        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 35 else { return }
        guard abs(loc.timestamp.timeIntervalSinceNow) < 15 else { return }

        // Smoothed speed over the last few fixes
        let spd = max(0, loc.speed)
        recentSpeeds.append(spd)
        if recentSpeeds.count > 5 { recentSpeeds.removeFirst() }
        let smoothed = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
        currentSpeed = smoothed

        // Auto-pause / auto-resume
        if settings?.autoPause == true {
            if state == .running, smoothed < 0.55 {
                stillCount += 1
                if stillCount >= 3 {
                    pauseNow(auto: true)
                    stillCount = 0
                }
            } else if state == .autoPaused, smoothed > 0.9 {
                resume()
                stillCount = 0
            } else {
                stillCount = 0
            }
        }

        guard state == .running else {
            // Keep anchors fresh while paused so nothing jumps on resume
            lastLocation = loc
            if loc.verticalAccuracy >= 0, loc.verticalAccuracy < 12 {
                lastAltitude = loc.altitude
            }
            return
        }

        let movingNow = accumulated + (segmentStart.map { Date().timeIntervalSince($0) } ?? 0)
        elapsed = movingNow

        // Distance + route
        if let last = lastLocation {
            let d = loc.distance(from: last)
            if d >= 2 {
                distance += d
                lastLocation = loc
                coordinates.append(loc.coordinate)
                points.append(RoutePoint(lat: loc.coordinate.latitude,
                                         lon: loc.coordinate.longitude,
                                         ele: loc.altitude,
                                         t: movingNow,
                                         speed: smoothed))
            }
        } else {
            lastLocation = loc
            coordinates.append(loc.coordinate)
            points.append(RoutePoint(lat: loc.coordinate.latitude,
                                     lon: loc.coordinate.longitude,
                                     ele: loc.altitude,
                                     t: movingNow,
                                     speed: smoothed))
        }

        // Elevation gain (threshold filters barometric/GPS noise)
        if loc.verticalAccuracy >= 0, loc.verticalAccuracy < 12 {
            if let lastAlt = lastAltitude {
                let delta = loc.altitude - lastAlt
                if delta > 1.2 {
                    elevationGain += delta
                    lastAltitude = loc.altitude
                } else if delta < -1.2 {
                    lastAltitude = loc.altitude
                }
            } else {
                lastAltitude = loc.altitude
            }
        }

        // Auto splits every km / mile
        let unitLen = (settings?.units ?? .metric).unitFactor
        while distance - lastSplitDistance >= unitLen {
            lastSplitDistance += unitLen
            let dur = movingNow - lastSplitTime
            splits.append(Split(index: splits.count + 1, duration: dur, distance: unitLen))
            lastSplitTime = movingNow
            haptic(.success)
        }
    }

    // MARK: - Cadence

    private func startPedometer() {
        guard CMPedometer.isCadenceAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let self = self, let cad = data?.currentCadence?.doubleValue else { return }
            DispatchQueue.main.async {
                let spm = cad * 60
                self.cadence = spm
                if self.state == .running {
                    self.cadenceSum += spm
                    self.cadenceCount += 1
                }
            }
        }
    }

    // MARK: - Haptics

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
