import SwiftUI

@main
struct StrideApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = RunStore()
    @StateObject private var tracker = RunTracker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(tracker)
                .preferredColorScheme(.dark)
                .onAppear { tracker.settings = settings }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            RunView()
                .tabItem { Label("Run", systemImage: "figure.run") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.ember)
    }
}
