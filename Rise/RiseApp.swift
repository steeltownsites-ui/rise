import SwiftUI

extension Color {
    static let riseGold  = Color(red: 0.79, green: 0.60, blue: 0.23)
    static let riseSoft  = Color(red: 0.96, green: 0.91, blue: 0.80)
    static let riseBG    = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.07, green: 0.067, blue: 0.063, alpha: 1)
        : UIColor(red: 0.953, green: 0.949, blue: 0.933, alpha: 1) })
    static let riseCard  = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.114, green: 0.106, blue: 0.094, alpha: 1) : .white })
}

@main
struct RiseApp: App {
    @StateObject private var store = AlarmStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .fullScreenCover(item: $store.active) { m in
                    MissionFlowView(mission: m)
                        .environmentObject(store)
                        .interactiveDismissDisabled()
                }
                .task { await store.requestAuthorization() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.reloadPending() }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house.fill") }
            InsightsView().tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.primary)
    }
}
