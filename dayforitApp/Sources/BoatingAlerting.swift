import BackgroundTasks
import Foundation
import UserNotifications
import WeatherCore

struct BoatingAlertPolicy {
    static let minimumScoreFloor = 75.0
    static let maximumLeadTime: TimeInterval = 10 * 24 * 60 * 60
    static let minimumRemainingWindow: TimeInterval = 90 * 60

    static func bestAlertCandidate(
        in recommendations: [OpportunityRecommendation],
        location: MarineLocation,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> OpportunityRecommendation? {
        recommendations
            .filter { shouldAlert(for: $0, location: location, now: now, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.finalScore == rhs.finalScore {
                    return lhs.window.start < rhs.window.start
                }
                return lhs.finalScore > rhs.finalScore
            }
            .first
    }

    static func shouldAlert(
        for recommendation: OpportunityRecommendation,
        location: MarineLocation,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard recommendation.activity == "boating" else { return false }
        guard recommendation.finalScore >= minimumScoreFloor else { return false }
        guard recommendation.confidence.lowercased() == "high" else { return false }
        guard isGreatBoatingWindow(recommendation) else { return false }
        guard hasKnownSeaData(recommendation) else { return false }
        guard isDefaultDaylightWindow(recommendation.window, calendar: calendar) else { return false }
        guard isAvailableBoatingDay(recommendation.window.start, location: location, calendar: calendar) else { return false }
        guard recommendation.window.end.timeIntervalSince(now) >= minimumRemainingWindow else { return false }
        guard recommendation.window.start.timeIntervalSince(now) <= maximumLeadTime else { return false }
        return true
    }

    static func isAvailableBoatingDay(
        _ date: Date,
        location: MarineLocation,
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return true
        }
        return AustralianPublicHolidayCalendar.isPublicHoliday(date, location: location, calendar: calendar)
    }

    static func alertDayKey(
        for recommendation: OpportunityRecommendation,
        location: MarineLocation,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: recommendation.window.start)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(locationKey(for: location))-\(String(format: "%04d-%02d-%02d", year, month, day))"
    }

    static func alertWindowKey(for recommendation: OpportunityRecommendation, location: MarineLocation) -> String {
        let start = Int(recommendation.window.start.timeIntervalSince1970 / 1_800)
        let end = Int(recommendation.window.end.timeIntervalSince1970 / 1_800)
        return "\(locationKey(for: location))-\(recommendation.activity)-\(start)-\(end)"
    }

    private static func isGreatBoatingWindow(_ recommendation: OpportunityRecommendation) -> Bool {
        let labels = [
            recommendation.analysis?.band,
            recommendation.decisionLabel,
            recommendation.verdict
        ]
            .compactMap { $0?.lowercased() }

        if labels.contains(where: { $0.contains("day_for_it") }) {
            return true
        }

        let hasExplicitNonIdealBand = labels.contains { label in
            label.contains("watch") || label.contains("marginal") || label.contains("not_recommended")
        }
        guard !hasExplicitNonIdealBand else { return false }

        let isHighPriority = recommendation.priority.lowercased() == "high"
        return isHighPriority && recommendation.finalScore >= 85 && recommendation.verdict.lowercased() == "recommended"
    }

    private static func isDefaultDaylightWindow(_ window: OpportunityRecommendation.Window, calendar: Calendar) -> Bool {
        guard calendar.isDate(window.start, inSameDayAs: window.end) else {
            return false
        }
        let startMinutes = calendar.component(.hour, from: window.start) * 60 + calendar.component(.minute, from: window.start)
        let endMinutes = calendar.component(.hour, from: window.end) * 60 + calendar.component(.minute, from: window.end)
        return startMinutes >= 5 * 60 && endMinutes <= 18 * 60
    }

    private static func hasKnownSeaData(_ recommendation: OpportunityRecommendation) -> Bool {
        let dataSignals = recommendation.analysis?.dataSignals.map { $0.lowercased() } ?? []
        let hasExplicitSeaSignal = dataSignals.contains { signal in
            signal.hasPrefix("wave ") || signal.hasPrefix("swell ") || signal.hasPrefix("sea ")
        }

        let seaFactorDetail = recommendation.analysis?.factors.first { factor in
            let lowerID = factor.id.lowercased()
            let lowerLabel = factor.label.lowercased()
            return lowerID.contains("sea") || lowerID.contains("swell") || lowerID.contains("wave") ||
                lowerLabel.contains("sea") || lowerLabel.contains("swell") || lowerLabel.contains("wave")
        }?.detail.lowercased() ?? ""

        let hasExplicitSeaFactor = seaFactorDetail.contains("roughness index") && !seaFactorDetail.contains("estimated from wind")
        let sourceStatus = recommendation.analysis?.sourceStatus.map { $0.lowercased() } ?? []
        let waveMissing = sourceStatus.contains { $0.contains("wave_height") && $0.contains("missing") }
        let swellMissing = sourceStatus.contains { $0.contains("swell_height") && $0.contains("missing") }
        let windOnly = recommendation.analysis?.band == "wind_led_watch" || seaFactorDetail.contains("estimated from wind")

        return (hasExplicitSeaSignal || hasExplicitSeaFactor) && !(waveMissing && swellMissing) && !windOnly
    }

    private static func locationKey(for location: MarineLocation) -> String {
        let lat = Int((location.latitude * 1_000).rounded())
        let lon = Int((location.longitude * 1_000).rounded())
        return "\(lat)_\(lon)"
    }
}

enum AustralianPublicHolidayCalendar {
    static func isPublicHoliday(
        _ date: Date,
        location: MarineLocation,
        calendar: Calendar = .current
    ) -> Bool {
        let jurisdiction = AustralianJurisdiction(location: location)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return false
        }

        let key = MonthDay(month, day)
        let stateWide = holidays[jurisdiction]?[year] ?? []
        if stateWide.contains(key) {
            return true
        }

        return capitalAreaHolidays(for: jurisdiction, year: year, location: location).contains(key)
    }

    private static func capitalAreaHolidays(
        for jurisdiction: AustralianJurisdiction,
        year: Int,
        location: MarineLocation
    ) -> Set<MonthDay> {
        switch jurisdiction {
        case .qld where location.isNear(latitude: -27.47, longitude: 153.03, withinKm: 90):
            return year == 2026 ? [.init(8, 12)] : year == 2027 ? [.init(8, 11)] : []
        case .tas where location.isNear(latitude: -42.88, longitude: 147.33, withinKm: 90):
            if year == 2026 {
                return [.init(2, 9), .init(10, 22)]
            }
            if year == 2027 {
                return [.init(2, 8), .init(10, 21)]
            }
            return []
        default:
            return []
        }
    }

    private static let holidays: [AustralianJurisdiction: [Int: Set<MonthDay>]] = [
        .act: [
            2026: [.init(1, 1), .init(1, 26), .init(3, 9), .init(4, 3), .init(4, 4), .init(4, 5), .init(4, 6), .init(4, 25), .init(4, 27), .init(6, 1), .init(6, 8), .init(10, 5), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 8), .init(3, 26), .init(3, 27), .init(3, 28), .init(3, 29), .init(4, 26), .init(5, 31), .init(6, 14), .init(10, 4), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ],
        .nsw: [
            2026: [.init(1, 1), .init(1, 26), .init(4, 3), .init(4, 4), .init(4, 5), .init(4, 6), .init(4, 25), .init(4, 27), .init(6, 8), .init(10, 5), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 26), .init(3, 27), .init(3, 28), .init(3, 29), .init(4, 25), .init(4, 26), .init(6, 14), .init(10, 4), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ],
        .nt: [
            2026: [.init(1, 1), .init(1, 26), .init(4, 3), .init(4, 4), .init(4, 5), .init(4, 6), .init(4, 25), .init(5, 4), .init(6, 8), .init(8, 3), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 26), .init(3, 27), .init(3, 28), .init(3, 29), .init(4, 26), .init(5, 3), .init(6, 14), .init(8, 2), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ],
        .qld: [
            2026: [.init(1, 1), .init(1, 26), .init(4, 3), .init(4, 4), .init(4, 5), .init(4, 6), .init(4, 25), .init(5, 4), .init(10, 5), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 26), .init(3, 27), .init(3, 28), .init(3, 29), .init(4, 26), .init(5, 3), .init(10, 4), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ],
        .sa: [
            2026: [.init(1, 1), .init(1, 26), .init(3, 9), .init(4, 3), .init(4, 4), .init(4, 5), .init(4, 6), .init(4, 25), .init(6, 8), .init(10, 5), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 8), .init(3, 26), .init(3, 27), .init(3, 28), .init(3, 29), .init(4, 25), .init(6, 14), .init(10, 4), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ],
        .tas: [
            2026: [.init(1, 1), .init(1, 26), .init(3, 9), .init(4, 3), .init(4, 6), .init(4, 25), .init(6, 8), .init(12, 25), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 8), .init(3, 26), .init(3, 29), .init(4, 25), .init(6, 14), .init(12, 25), .init(12, 27), .init(12, 28)]
        ],
        .vic: [
            2026: [.init(1, 1), .init(1, 26), .init(3, 9), .init(4, 3), .init(4, 4), .init(4, 5), .init(4, 6), .init(4, 25), .init(6, 8), .init(11, 3), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 8), .init(3, 26), .init(3, 27), .init(3, 28), .init(3, 29), .init(4, 25), .init(6, 14), .init(11, 2), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ],
        .wa: [
            2026: [.init(1, 1), .init(1, 26), .init(3, 2), .init(4, 3), .init(4, 5), .init(4, 6), .init(4, 25), .init(4, 27), .init(6, 1), .init(9, 28), .init(12, 25), .init(12, 26), .init(12, 28)],
            2027: [.init(1, 1), .init(1, 26), .init(3, 1), .init(3, 26), .init(3, 28), .init(3, 29), .init(4, 25), .init(4, 26), .init(6, 7), .init(9, 27), .init(12, 25), .init(12, 26), .init(12, 27), .init(12, 28)]
        ]
    ]
}

private enum AustralianJurisdiction: Hashable {
    case act
    case nsw
    case nt
    case qld
    case sa
    case tas
    case vic
    case wa

    init(location: MarineLocation) {
        switch location.timeZoneID {
        case "Australia/Brisbane":
            self = .qld
        case "Australia/Sydney":
            self = location.latitude < -35.0 && location.longitude < 150.0 ? .act : .nsw
        case "Australia/Darwin":
            self = .nt
        case "Australia/Adelaide":
            self = .sa
        case "Australia/Hobart":
            self = .tas
        case "Australia/Melbourne":
            self = .vic
        case "Australia/Perth":
            self = .wa
        default:
            if (-29.5 ... -9.0).contains(location.latitude), (137.5 ... 154.5).contains(location.longitude) {
                self = .qld
            } else if location.longitude >= 129, location.longitude < 138 {
                self = .wa
            } else if location.latitude < -39 {
                self = .tas
            } else if location.longitude < 141 {
                self = location.latitude > -26 ? .nt : .sa
            } else if location.latitude < -36 {
                self = .vic
            } else {
                self = .nsw
            }
        }
    }
}

private struct MonthDay: Hashable {
    let month: Int
    let day: Int

    init(_ month: Int, _ day: Int) {
        self.month = month
        self.day = day
    }
}

private extension MarineLocation {
    func isNear(latitude targetLatitude: Double, longitude targetLongitude: Double, withinKm maxDistance: Double) -> Bool {
        let radiusKm = 6371.0
        let dLat = (targetLatitude - latitude) * .pi / 180
        let dLon = (targetLongitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(latitude * .pi / 180) * cos(targetLatitude * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        return 2 * radiusKm * atan2(sqrt(a), sqrt(max(0, 1 - a))) <= maxDistance
    }
}

enum BoatingAlertScheduler {
    static let taskIdentifier = "com.hmalc.dayforit.boating-alert-refresh"
    static let checkHours = [7, 12, 17]

    static func scheduleNextCheck(after date: Date = Date(), calendar: Calendar = .current) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextCheckDate(after: date, calendar: calendar)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func cancelScheduledChecks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    static func nextCheckDate(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        for hour in checkHours {
            guard let candidate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else {
                continue
            }
            if candidate > date {
                return candidate
            }
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(24 * 60 * 60)
        return calendar.date(byAdding: .hour, value: checkHours[0], to: tomorrow) ?? tomorrow
    }
}

struct BoatingAlertStateStore {
    private let defaults: UserDefaults
    private let enabledKey = "boating_alerts_enabled_v2"
    private let alertedDayKeysKey = "boating_alerted_day_keys_v2"
    private let alertedWindowKeysKey = "boating_alerted_window_keys_v2"
    private let lastCheckDateKey = "boating_alert_last_check_date_v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var alertsEnabled: Bool {
        get {
            if defaults.object(forKey: enabledKey) != nil {
                return defaults.bool(forKey: enabledKey)
            }
            if defaults.object(forKey: "cowley_boating_alerts_enabled_v1") != nil {
                return defaults.bool(forKey: "cowley_boating_alerts_enabled_v1")
            }
            return true
        }
        set {
            defaults.set(newValue, forKey: enabledKey)
        }
    }

    var lastCheckDate: Date? {
        defaults.object(forKey: lastCheckDateKey) as? Date ??
            defaults.object(forKey: "cowley_boating_alert_last_check_date_v1") as? Date
    }

    func recordCheck(at date: Date) {
        defaults.set(date, forKey: lastCheckDateKey)
    }

    func hasAlreadyAlerted(
        _ recommendation: OpportunityRecommendation,
        location: MarineLocation,
        calendar: Calendar = .current
    ) -> Bool {
        let dayKey = BoatingAlertPolicy.alertDayKey(for: recommendation, location: location, calendar: calendar)
        let windowKey = BoatingAlertPolicy.alertWindowKey(for: recommendation, location: location)
        return Set(defaults.stringArray(forKey: alertedDayKeysKey) ?? []).contains(dayKey) ||
            Set(defaults.stringArray(forKey: alertedWindowKeysKey) ?? []).contains(windowKey)
    }

    func markAlerted(
        _ recommendation: OpportunityRecommendation,
        location: MarineLocation,
        calendar: Calendar = .current
    ) {
        let dayKey = BoatingAlertPolicy.alertDayKey(for: recommendation, location: location, calendar: calendar)
        let windowKey = BoatingAlertPolicy.alertWindowKey(for: recommendation, location: location)
        defaults.set(prunedKeys((defaults.stringArray(forKey: alertedDayKeysKey) ?? []) + [dayKey]), forKey: alertedDayKeysKey)
        defaults.set(prunedKeys((defaults.stringArray(forKey: alertedWindowKeysKey) ?? []) + [windowKey]), forKey: alertedWindowKeysKey)
    }

    private func prunedKeys(_ keys: [String]) -> [String] {
        Array(NSOrderedSet(array: keys.suffix(60)).compactMap { $0 as? String })
    }
}

enum BoatingAlertCheckResult: Equatable {
    case disabled
    case notificationsUnavailable
    case noHighQualityWindow
    case alreadyAlerted
    case notified(String)
    case failed(String)

    var message: String {
        switch self {
        case .disabled:
            return "Alerts are off."
        case .notificationsUnavailable:
            return "Notifications are not allowed yet."
        case .noHighQualityWindow:
            return "No high-confidence weekend or public-holiday boating window right now."
        case .alreadyAlerted:
            return "Already alerted for the current best boating day."
        case let .notified(window):
            return "Alert sent for \(window)."
        case let .failed(message):
            return message
        }
    }
}

@MainActor
protocol DayForItNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: DayForItNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

@MainActor
final class BoatingAlertService {
    private let opportunityClient: OpportunityClientProtocol
    private let clientIDStore: OpportunityClientIDStore
    private let notificationCenter: DayForItNotificationCenter
    private var stateStore: BoatingAlertStateStore

    init(
        opportunityClient: OpportunityClientProtocol = OpportunityClient(),
        clientIDStore: OpportunityClientIDStore = .init(),
        notificationCenter: DayForItNotificationCenter = UNUserNotificationCenter.current(),
        stateStore: BoatingAlertStateStore = .init()
    ) {
        self.opportunityClient = opportunityClient
        self.clientIDStore = clientIDStore
        self.notificationCenter = notificationCenter
        self.stateStore = stateStore
    }

    var alertsEnabled: Bool {
        stateStore.alertsEnabled
    }

    var lastCheckDate: Date? {
        stateStore.lastCheckDate
    }

    func setAlertsEnabled(_ enabled: Bool) {
        stateStore.alertsEnabled = enabled
        if enabled {
            BoatingAlertScheduler.scheduleNextCheck()
        } else {
            BoatingAlertScheduler.cancelScheduledChecks()
        }
    }

    func authorizationText() async -> String {
        let status = await notificationCenter.authorizationStatus()
        return text(for: status)
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await notificationCenter.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func checkForAlert(
        location: MarineLocation,
        canRequestAuthorization: Bool,
        now: Date = Date()
    ) async -> BoatingAlertCheckResult {
        guard stateStore.alertsEnabled else { return .disabled }
        stateStore.recordCheck(at: now)

        if canRequestAuthorization {
            guard await requestAuthorizationIfNeeded() else {
                return .notificationsUnavailable
            }
        } else {
            let status = await notificationCenter.authorizationStatus()
            guard notificationStatusAllowsAlerts(status) else {
                return .notificationsUnavailable
            }
        }

        do {
            let response = try await opportunityClient.scan(
                location: location,
                clientID: clientIDStore.loadOrCreate(),
                interests: ["boating"]
            )
            guard let candidate = BoatingAlertPolicy.bestAlertCandidate(in: response.recommendations, location: location, now: now) else {
                return .noHighQualityWindow
            }
            guard !stateStore.hasAlreadyAlerted(candidate, location: location) else {
                return .alreadyAlerted
            }

            let window = Self.windowText(for: candidate.window)
            try await notificationCenter.add(Self.notificationRequest(for: candidate, location: location, windowText: window))
            stateStore.markAlerted(candidate, location: location)
            return .notified(window)
        } catch {
            return .failed("Could not check boating alerts. Pull to retry in the app.")
        }
    }

    private func notificationStatusAllowsAlerts(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func text(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Quietly allowed"
        case .ephemeral:
            return "Temporarily allowed"
        case .denied:
            return "Denied in Settings"
        case .notDetermined:
            return "Not asked yet"
        @unknown default:
            return "Unknown"
        }
    }

    private static func notificationRequest(
        for recommendation: OpportunityRecommendation,
        location: MarineLocation,
        windowText: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "\(location.name): day for it"
        content.body = "\(windowText) looks genuinely calm with wave height and swell data behind it. Check official warnings before heading out."
        content.sound = .default
        content.userInfo = [
            "recommendation_id": recommendation.id,
            "location_name": location.name,
            "window_start": recommendation.window.start.ISO8601Format(),
            "window_end": recommendation.window.end.ISO8601Format()
        ]

        return UNNotificationRequest(
            identifier: "boating-\(BoatingAlertPolicy.alertWindowKey(for: recommendation, location: location))",
            content: content,
            trigger: nil
        )
    }

    private static func windowText(for window: OpportunityRecommendation.Window) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(window.start) {
            day = "Today"
        } else if calendar.isDateInTomorrow(window.start) {
            day = "Tomorrow"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            day = dayFormatter.string(from: window.start)
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let start = timeFormatter.string(from: window.start).lowercased()
        let end = timeFormatter.string(from: window.end).lowercased()
        return "\(day) \(start)-\(end)"
    }
}

final class DayForItNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
