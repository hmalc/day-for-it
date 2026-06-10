import Foundation
import BackgroundTasks
import UserNotifications
import WeatherCore
import PleasantnessEngine

enum DayForItAlerts {
    static let taskIdentifier = "com.hmalc.dayforit.refresh"
    static let enabledDefaultsKey = "day_for_it_alerts_enabled_v1"
    static let notifiedDefaultsKey = "day_for_it_alerts_notified_v1"
    /// BOM coastal forecasts are reissued a few times a day; checking more often buys nothing.
    static let refreshInterval: TimeInterval = 4 * 60 * 60
}

struct DayForItAlertPlan: Equatable {
    let dayStart: Date
    let title: String
    let body: String
    let key: String
}

/// Decides which upcoming "Day for it" days deserve a notification.
/// Pure logic: forecast in, plans out. One notification per day per location, ever.
enum DayForItAlertPlanner {
    static func plans(
        daily: [DailyMarineSummary],
        locationName: String,
        alreadyNotified: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayForItAlertPlan] {
        let today = calendar.startOfDay(for: now)
        return daily
            .filter { $0.verdict == .dayForIt && $0.dayStart >= today }
            .compactMap { day in
                let key = notificationKey(dayStart: day.dayStart, locationName: locationName)
                guard !alreadyNotified.contains(key) else { return nil }
                let label = dayLabel(for: day.dayStart, today: today, calendar: calendar)
                let reason = day.limitedBy ?? "Light winds and low seas forecast"
                return DayForItAlertPlan(
                    dayStart: day.dayStart,
                    title: label == "Today" ? "Today's a day for it" : "\(label) is a day for it",
                    body: "\(reason) · \(locationName)",
                    key: key
                )
            }
    }

    static func notificationKey(dayStart: Date, locationName: String) -> String {
        "\(Self.dayFormatter.string(from: dayStart))|\(locationName)"
    }

    /// Drops ledger keys for days that have passed, so the store stays tiny.
    static func prune(keys: Set<String>, now: Date = Date(), calendar: Calendar = .current) -> Set<String> {
        let today = calendar.startOfDay(for: now)
        return keys.filter { key in
            guard let datePart = key.split(separator: "|").first,
                  let date = Self.dayFormatter.date(from: String(datePart)) else { return false }
            return date >= today
        }
    }

    private static func dayLabel(for date: Date, today: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return Self.weekdayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_AU_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}

/// Remembers which day/location alerts have already been sent.
struct DayForItAlertLedger {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func notifiedKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: DayForItAlerts.notifiedDefaultsKey) ?? [])
    }

    func markNotified(_ keys: [String], now: Date = Date()) {
        let merged = DayForItAlertPlanner.prune(keys: notifiedKeys().union(keys), now: now)
        defaults.set(Array(merged).sorted(), forKey: DayForItAlerts.notifiedDefaultsKey)
    }
}

/// Fetches the forecast in the background and posts local notifications
/// for newly appeared "Day for it" days.
enum DayForItAlertService {
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DayForItAlerts.enabledDefaultsKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: DayForItAlerts.enabledDefaultsKey)
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    static func scheduleNextRefreshIfEnabled() {
        guard isEnabled() else { return }
        let request = BGAppRefreshTaskRequest(identifier: DayForItAlerts.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: DayForItAlerts.refreshInterval)
        // Submitting again with the same identifier replaces the pending request.
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleBackgroundRefresh() async {
        defer { scheduleNextRefreshIfEnabled() }
        guard isEnabled() else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral else { return }

        let location = LocationFeedResolver.effectiveLocation(override: LocationStore().load())
        let request = MarineForecastRequest(
            location: location,
            feed: LocationFeedResolver.feedConfig(for: location),
            forecastDays: 7
        )
        guard let output = try? await MarineForecastService().fetchSevenDayForecast(request: request) else { return }

        let ledger = DayForItAlertLedger()
        let plans = DayForItAlertPlanner.plans(
            daily: output.daily,
            locationName: location.name,
            alreadyNotified: ledger.notifiedKeys()
        )
        guard !plans.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let request = UNNotificationRequest(identifier: plan.key, content: content, trigger: nil)
            try? await center.add(request)
        }
        ledger.markNotified(plans.map(\.key))
    }
}
