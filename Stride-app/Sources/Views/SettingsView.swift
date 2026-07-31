import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Distance units", selection: $settings.units) {
                        ForEach(Units.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                }
                Section {
                    Stepper(value: $settings.weightKg, in: 40...160, step: 1) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            Text("\(Int(settings.weightKg)) kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Body")
                } footer: {
                    Text("Used to estimate calories burned (~1 kcal per kg per km).")
                }
                Section {
                    Toggle("Auto-pause when stopped", isOn: $settings.autoPause)
                } header: {
                    Text("Tracking")
                } footer: {
                    Text("Pauses the clock automatically at traffic lights and resumes when you move again.")
                }
                Section("About") {
                    LabeledContent("App", value: "Stride 1.0")
                    LabeledContent("Data", value: "Stays on this device")
                    LabeledContent("Export", value: "GPX per run via Share")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}
