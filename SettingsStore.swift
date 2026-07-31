import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @Published var units: Units {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: "units") }
    }
    @Published var weightKg: Double {
        didSet { UserDefaults.standard.set(weightKg, forKey: "weightKg") }
    }
    @Published var autoPause: Bool {
        didSet { UserDefaults.standard.set(autoPause, forKey: "autoPause") }
    }

    init() {
        let d = UserDefaults.standard
        units = Units(rawValue: d.string(forKey: "units") ?? "") ?? .metric
        weightKg = (d.object(forKey: "weightKg") as? Double) ?? 70
        autoPause = (d.object(forKey: "autoPause") as? Bool) ?? true
    }
}
