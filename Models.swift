import Foundation
import CoreLocation
import SwiftUI

// MARK: - Core data types

struct RoutePoint: Codable {
    var lat: Double
    var lon: Double
    var ele: Double
    var t: TimeInterval      // moving time (seconds) at capture
    var speed: Double        // m/s, smoothed

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Split: Codable, Identifiable {
    var id: UUID = UUID()
    var index: Int           // 1-based
    var duration: TimeInterval
    var distance: Double     // meters (full unit length, last one may be partial)
}

struct RunRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var duration: TimeInterval   // moving time, seconds
    var distance: Double         // meters
    var elevationGain: Double    // meters
    var calories: Double
    var avgCadence: Double?      // steps per minute
    var points: [RoutePoint]
    var splits: [Split]

    var avgSpeed: Double { duration > 0 ? distance / duration : 0 }   // m/s
}

// MARK: - Units

enum Units: String, Codable, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var label: String { self == .metric ? "Kilometers" : "Miles" }
    var unitFactor: Double { self == .metric ? 1000.0 : 1609.344 }   // meters per unit
    var distanceSymbol: String { self == .metric ? "km" : "mi" }
    var paceSymbol: String { self == .metric ? "/km" : "/mi" }
    var speedSymbol: String { self == .metric ? "km/h" : "mph" }
    var speedFactor: Double { self == .metric ? 3.6 : 2.23694 }      // m/s -> unit/h
}

// MARK: - Formatting

enum Format {
    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    static func distance(_ meters: Double, units: Units) -> String {
        String(format: "%.2f", meters / units.unitFactor)
    }

    static func pace(secondsPerUnit: Double) -> String {
        guard secondsPerUnit.isFinite, secondsPerUnit > 0, secondsPerUnit < 3600 else { return "--:--" }
        let s = Int(secondsPerUnit.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func pace(metersPerSecond: Double, units: Units) -> String {
        guard metersPerSecond > 0.25 else { return "--:--" }
        return pace(secondsPerUnit: units.unitFactor / metersPerSecond)
    }
}

// MARK: - Palette

extension Color {
    static let appBackground = Color(red: 0.055, green: 0.067, blue: 0.086)   // deep ink
    static let card = Color(red: 0.098, green: 0.118, blue: 0.149)
    static let ember = Color(red: 1.0, green: 0.353, blue: 0.212)             // primary accent
    static let amber = Color(red: 1.0, green: 0.690, blue: 0.125)             // elevation / records
    static let ink = Color(red: 0.043, green: 0.051, blue: 0.063)
}

// MARK: - Chart samples

struct DistanceSample: Identifiable {
    let id = UUID()
    let x: Double       // distance in current unit
    let value: Double
}

extension RunRecord {
    /// Downsampled pace and elevation series for charts.
    func series(units: Units) -> (pace: [DistanceSample], elevation: [DistanceSample]) {
        var pace: [DistanceSample] = []
        var elev: [DistanceSample] = []
        guard points.count > 1 else { return (pace, elev) }

        var cum: Double = 0
        var lastLoc = CLLocation(latitude: points[0].lat, longitude: points[0].lon)
        var lastSampled: Double = -100

        for p in points {
            let loc = CLLocation(latitude: p.lat, longitude: p.lon)
            cum += loc.distance(from: lastLoc)
            lastLoc = loc
            if cum - lastSampled >= 40 {
                lastSampled = cum
                let x = cum / units.unitFactor
                if p.speed > 0.4 {
                    let secPerUnit = units.unitFactor / p.speed
                    if secPerUnit < 1500 {
                        pace.append(DistanceSample(x: x, value: secPerUnit / 60))   // minutes per unit
                    }
                }
                elev.append(DistanceSample(x: x, value: p.ele))
            }
        }
        return (pace, elev)
    }
}

// MARK: - GPX export

enum GPX {
    static func document(for run: RunRecord) -> String {
        let fmt = ISO8601DateFormatter()
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        s += "<gpx version=\"1.1\" creator=\"Stride\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        s += "<trk><name>Run \(fmt.string(from: run.date))</name><trkseg>"
        for p in run.points {
            let t = fmt.string(from: run.date.addingTimeInterval(p.t))
            s += "\n<trkpt lat=\"\(p.lat)\" lon=\"\(p.lon)\"><ele>\(String(format: "%.1f", p.ele))</ele><time>\(t)</time></trkpt>"
        }
        s += "\n</trkseg></trk>\n</gpx>\n"
        return s
    }
}
