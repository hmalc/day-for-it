import SwiftUI
import UserNotifications

@main
struct dayforitApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()
    private let notificationDelegate = DayForItNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .backgroundTask(.appRefresh(BoatingAlertScheduler.taskIdentifier)) {
            await model.handleBoatingAlertBackgroundTask()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.scheduleBoatingAlertRefreshIfNeeded()
            }
        }
    }
}
