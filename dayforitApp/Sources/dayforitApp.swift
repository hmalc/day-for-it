import SwiftUI

@main
struct dayforitApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        DayForItAlertService.scheduleNextRefreshIfEnabled()
                    }
                }
        }
        .backgroundTask(.appRefresh(DayForItAlerts.taskIdentifier)) {
            await DayForItAlertService.handleBackgroundRefresh()
        }
    }
}
