import Foundation
import CoreLocation
import SwiftUI
import PleasantnessEngine
import WeatherCore

enum TideEventKindView: String {
    case high
    case low
}

struct TideEventViewPoint: Identifiable {
    let id = UUID()
    let time: Date
    let kind: TideEventKindView
    let heightMeters: Double?
    let isDerivedHeight: Bool
}

struct TideSamplePoint: Identifiable {
    let id = UUID()
    let time: Date
    let heightMeters: Double
    let isDerived: Bool
}

enum TideSeriesSource {
    case sampled([TideSamplePoint])
    case eventInterpolated([TideSamplePoint])
    case unavailable
}

struct TideProbe: Equatable {
    let time: Date
    let heightMeters: Double?
    let stateLabel: String
    let isEstimated: Bool
}

struct TideCardViewData: Identifiable {
    let id: Date
    let dayLabel: String
    let windowLabel: String
    let stateLabel: String
    let nextHigh: TideEventViewPoint?
    let nextLow: TideEventViewPoint?
    let events: [TideEventViewPoint]
    let series: TideSeriesSource
    let axisStart: Date
    let axisEnd: Date
    let note: String?
}

struct FourDayDetailPage: Identifiable {
    let id = UUID()
    let sourceIndex: Int
    let dayLabel: String
    let dateText: String
    let verdict: DayVerdict?
    let summaryText: String
    let confidenceText: String
    let contextText: String?
    let warningText: String
    let topDrivers: [String]
    let isBest: Bool
}

struct HeroOpportunitySummary {
    let headline: String
    let subheadline: String
    let tone: DayVerdict?
    let badgeText: String
    let focusDrivers: [String]
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDayIndex = 0
    @Published var output: MarineForecastOutput?
    @Published var warningBanner: String?
    @Published var disclaimer = "For planning only. Uses Bureau marine data Australia-wide where configured, with Queensland Government tide and wave data where available."
    @Published var savedOverride: StoredLocation?
    @Published var tideForecast: TideForecast?
    @Published var tideStatusMessage: String?
    @Published var alertsEnabled = DayForItAlertService.isEnabled()
    @Published var alertsPermissionDenied = false

    let locationManager: LocationManager

    private let forecastService: MarineForecastService
    private let locationStore: LocationStore
    private let tideProvider: TideDataProvider
    private let tideStore: TideStore
    private var pendingCurrentLocationSelection = false
    private var refreshGeneration = 0

    init(
        locationManager: LocationManager = .init(),
        forecastService: MarineForecastService = .init(),
        locationStore: LocationStore = .init(),
        tideProvider: TideDataProvider = QueenslandTideDataProvider()
    ) {
        self.locationManager = locationManager
        self.forecastService = forecastService
        self.locationStore = locationStore
        self.tideProvider = tideProvider
        self.tideStore = .init()
        savedOverride = locationStore.load()
        tideForecast = tideStore.load()
        self.locationManager.onCoordinateUpdate = { [weak self] _ in
            guard let self else { return }
            if self.pendingCurrentLocationSelection {
                self.applyCurrentLocationIfAvailable()
            }
        }
    }

    var hasData: Bool { output != nil }

    var availableLocationPresets: [LocationPreset] {
        LocationPreset.all
    }

    var selectedDaySummary: DailyMarineSummary? {
        output?.daily[safe: selectedDayIndex]
    }

    var topDrivers: [String] {
        selectedDaySummary?.topDrivers ?? []
    }

    var activeLocationName: String {
        output?.location.name ?? effectiveLocation().name
    }

    private var forecastDisplayWindow: [(sourceIndex: Int, day: DailyMarineSummary)] {
        let indexedDays = Array(displayDays.enumerated()).map { (sourceIndex: $0.offset, day: $0.element) }
        let firstFour = Array(indexedDays.prefix(4))
        let called = firstFour.filter { $0.day.verdict != nil }
        return called.isEmpty ? firstFour : called
    }

    var heroOpportunitySummary: HeroOpportunitySummary {
        let called = forecastDisplayWindow.filter { $0.day.verdict != nil }
        guard let best = called.max(by: { lhs, rhs in
            let left = lhs.day.verdict ?? .notAChance
            let right = rhs.day.verdict ?? .notAChance
            if left == right {
                return lhs.sourceIndex > rhs.sourceIndex
            }
            return left < right
        }), let verdict = best.day.verdict else {
            return HeroOpportunitySummary(
                headline: "Checking the ocean",
                subheadline: "Forecast loading. Pull to refresh if this persists.",
                tone: nil,
                badgeText: "CHECKING",
                focusDrivers: []
            )
        }

        let bestLabel = dayLabel(for: best.day.dayStart, index: best.sourceIndex)
        let goodLabels = called
            .filter { ($0.day.verdict ?? .notAChance) >= .decent }
            .map { dayLabel(for: $0.day.dayStart, index: $0.sourceIndex) }
            .uniquePrefix(3)

        let headline: String
        switch verdict {
        case .dayForIt:
            headline = bestLabel == "Today" ? "Today's a day for it" : "\(bestLabel) is a day for it"
        case .decent:
            headline = "Decent: \(goodLabels.joined(separator: ", "))"
        case .ifYouMust:
            headline = "Only if you must"
        case .poor:
            headline = "Hold off for now"
        case .notAChance:
            headline = "Not a chance out there"
        }

        let subheadline: String
        if verdict >= .decent {
            subheadline = conciseReason(from: best.day.topDrivers) ?? "Wind and seas look workable."
        } else if let limitedBy = best.day.limitedBy {
            subheadline = "Held back by: \(limitedBy.prefix(1).lowercased() + limitedBy.dropFirst())."
        } else {
            subheadline = conciseReason(from: best.day.topDrivers) ?? "Wind and sea state are the blockers."
        }

        return HeroOpportunitySummary(
            headline: headline,
            subheadline: subheadline,
            tone: verdict,
            badgeText: verdict.label.uppercased(),
            focusDrivers: best.day.topDrivers
        )
    }

    var lastUpdatedText: String? {
        guard let date = output?.generatedAt else { return nil }
        if abs(date.timeIntervalSinceNow) < 45 {
            return "Just now"
        }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    var heroWindText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "wind", fallback: "Calm")
    }

    var heroWavesText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "swell", alternateKeywords: ["sea", "wave"], fallback: "Low")
    }

    var heroTideText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "tide", fallback: "No tide signal")
    }

    var fourDayDetailPages: [FourDayDetailPage] {
        let days = forecastDisplayWindow
        let bestVerdict = days.compactMap { $0.day.verdict }.max()
        return days.enumerated().map { displayIndex, item in
            let day = item.day
            let isBest = day.verdict != nil && day.verdict == bestVerdict && (bestVerdict ?? .notAChance) >= .decent
            let dayLabel = dayLabel(for: day.dayStart, index: displayIndex)
            let dateText = Self.detailDateFormatter.string(from: day.dayStart)
            let drivers = visibleDriverTexts(from: day.topDrivers)
            let summaryText = day.limitedBy ?? conciseReason(from: drivers) ?? "Forecast details unavailable"
            let confidenceText = day.confidence.capitalized
            let contextText = forecastContextText(for: day, isBest: isBest)
            let warningText = day.warningLimited ? "Warning active" : "No warnings"
            return FourDayDetailPage(
                sourceIndex: item.sourceIndex,
                dayLabel: dayLabel,
                dateText: dateText,
                verdict: day.verdict,
                summaryText: summaryText,
                confidenceText: confidenceText,
                contextText: contextText,
                warningText: warningText,
                topDrivers: drivers,
                isBest: isBest
            )
        }
    }

    var tidePageViewData: [TideCardViewData] {
        (0 ..< 4).map { buildTideCardViewData(pageOffset: $0) }
    }

    var displayDays: [DailyMarineSummary] {
        if let output {
            return output.daily
        }
        let today = Calendar.current.startOfDay(for: Date())
        return (0 ..< 7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DailyMarineSummary(
                dayStart: date,
                verdict: nil,
                limitedBy: nil,
                confidence: "low",
                warningLimited: false,
                topDrivers: []
            )
        }
    }

    func startup() {
        // Default to Cowley Beach unless user explicitly sets an override.
        Task { await refreshFullData(clearsExistingData: false, allowsCachedTideFallback: true) }
    }

    func refresh() async {
        await refreshFullData(clearsExistingData: true, allowsCachedTideFallback: false)
    }

    func setAlertsEnabled(_ enabled: Bool) async {
        guard enabled else {
            alertsEnabled = false
            alertsPermissionDenied = false
            DayForItAlertService.setEnabled(false)
            return
        }
        let authorized = await DayForItAlertService.requestAuthorization()
        alertsEnabled = authorized
        alertsPermissionDenied = !authorized
        DayForItAlertService.setEnabled(authorized)
        if authorized {
            DayForItAlertService.scheduleNextRefreshIfEnabled()
        }
    }

    private func refreshFullData(clearsExistingData: Bool, allowsCachedTideFallback: Bool) async {
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        errorMessage = nil
        tideStatusMessage = nil
        if clearsExistingData {
            clearDisplayedData(clearStoredTide: true)
        }
        defer {
            if isCurrentRefresh(generation) {
                isLoading = false
            }
        }

        let request = makeRequest()
        do {
            async let forecastTask = forecastService.fetchSevenDayForecast(request: request)
            async let tideTask: TideForecast? = try? tideProvider.fetchTideForecast(
                location: request.location,
                start: Date(),
                days: 5,
                sampleIntervalMinutes: nil
            )

            let forecast = try await forecastTask
            let tide = await tideTask
            guard isCurrentRefresh(generation) else { return }

            output = forecast
            warningBanner = forecast.daily.prefix(4).contains(where: \.warningLimited) ? forecast.warnings.first?.title : nil
            selectedDayIndex = 0
            errorMessage = forecast.degradedReason

            applyTideForecast(tide, allowsCachedFallback: allowsCachedTideFallback)
        } catch {
            guard isCurrentRefresh(generation) else { return }

            let message: String
            if let urlError = error as? URLError {
                message = "Network error (\(urlError.code.rawValue)). Pull to retry."
            } else {
                message = "Could not load latest forecast (\(error.localizedDescription)). Pull to retry."
            }
            errorMessage = message
            if allowsCachedTideFallback, let existing = tideForecast, !existing.days.isEmpty {
                tideStatusMessage = "Using cached official tide data."
            } else {
                tideForecast = nil
                tideStore.save(nil)
                tideStatusMessage = "Official tide data unavailable."
            }
        }
    }

    func select(dayIndex: Int) {
        guard let output, output.daily.indices.contains(dayIndex) else { return }
        selectedDayIndex = dayIndex
    }

    func saveLocationOverride(name: String, latitude: Double, longitude: Double, timeZoneID: String = "Australia/Brisbane") {
        let stored = StoredLocation(name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID)
        savedOverride = stored
        locationStore.save(stored)
        refreshAfterLocationChange()
    }

    func saveLocationPreset(_ preset: LocationPreset) {
        savedOverride = preset.storedLocation
        locationStore.save(preset.storedLocation)
        refreshAfterLocationChange()
    }

    func clearLocationOverride() {
        savedOverride = nil
        locationStore.save(nil)
        refreshAfterLocationChange()
    }

    func useCurrentLocation() {
        pendingCurrentLocationSelection = true
        locationManager.requestIfNeeded()
        applyCurrentLocationIfAvailable()
    }

    func effectiveLocation() -> MarineLocation {
        LocationFeedResolver.effectiveLocation(override: savedOverride)
    }

    func effectiveFeedConfig() -> MarineFeedConfig {
        LocationFeedResolver.feedConfig(for: effectiveLocation())
    }

    private func makeRequest() -> MarineForecastRequest {
        MarineForecastRequest(
            location: effectiveLocation(),
            feed: effectiveFeedConfig(),
            forecastDays: 7
        )
    }

    func supportsManualLocation(latitude: Double, longitude: Double) -> Bool {
        LocationFeedResolver.supportsManualLocation(latitude: latitude, longitude: longitude)
    }

    private func applyCurrentLocationIfAvailable() {
        guard let coordinate = locationManager.currentCoordinate else { return }
        guard supportsManualLocation(latitude: coordinate.latitude, longitude: coordinate.longitude) else {
            pendingCurrentLocationSelection = false
            errorMessage = "Current location is outside the supported Australian coastal coverage areas."
            return
        }
        let timeZoneID = LocationFeedResolver.timeZoneID(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let stored = StoredLocation(
            name: "Current location",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZoneID: timeZoneID
        )
        pendingCurrentLocationSelection = false
        savedOverride = stored
        locationStore.save(stored)
        refreshAfterLocationChange()
    }

    private func refreshAfterLocationChange() {
        refreshGeneration += 1
        isLoading = true
        errorMessage = nil
        clearDisplayedData(clearStoredTide: true)
        Task {
            await refreshFullData(clearsExistingData: false, allowsCachedTideFallback: false)
        }
    }

    private func clearDisplayedData(clearStoredTide: Bool) {
        output = nil
        tideForecast = nil
        warningBanner = nil
        tideStatusMessage = nil
        selectedDayIndex = 0
        if clearStoredTide {
            tideStore.save(nil)
        }
    }

    private func isCurrentRefresh(_ generation: Int) -> Bool {
        refreshGeneration == generation
    }

    private func applyTideForecast(_ tide: TideForecast?, allowsCachedFallback: Bool) {
        if let tide, !tide.days.isEmpty {
            tideForecast = tide
            tideStore.save(tide)
            tideStatusMessage = tideStationStatusMessage(for: tide)
        } else if allowsCachedFallback, let existing = tideForecast, !existing.days.isEmpty {
            tideStatusMessage = "Using cached official tide data."
        } else {
            tideForecast = nil
            tideStore.save(nil)
            tideStatusMessage = "Official tide data unavailable."
        }
    }

    private func tideStationStatusMessage(for tide: TideForecast) -> String? {
        guard let station = tide.stationName else { return nil }
        if let distance = tide.stationDistanceKm, distance > 120 {
            return "Nearest station: \(station) (\(Int(distance.rounded())) km)"
        }
        return "Station: \(station)"
    }

    private var heroFocusDrivers: [String] {
        let drivers = heroOpportunitySummary.focusDrivers
        return drivers.isEmpty ? topDrivers : drivers
    }

    private func conciseReason(from drivers: [String]) -> String? {
        guard let first = visibleDriverTexts(from: drivers).first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty else {
            return nil
        }
        if let period = first.firstIndex(of: ".") {
            return String(first[...period])
        }
        return String(first.prefix(92))
    }

    private func forecastContextText(for day: DailyMarineSummary, isBest: Bool) -> String? {
        var parts: [String] = []
        if isBest {
            parts.append("Best current window")
        }
        parts.append(day.verdict != nil ? "official forecast available" : "limited official data")
        parts.append("\(day.confidence.lowercased()) confidence")
        parts.append(day.warningLimited ? "warning caps the day" : "worst factor decides")
        return parts.joined(separator: " · ")
    }

    private func dayLabel(for date: Date, index: Int) -> String {
        if index == 0 { return "Today" }
        if index == 1 { return "Tomorrow" }
        return Self.dayFormatter.string(from: date)
    }

    private func conciseDriverValue(in sourceDrivers: [String], keyword: String, alternateKeywords: [String] = [], fallback: String) -> String {
        let keys = [keyword] + alternateKeywords
        guard let source = visibleDriverTexts(from: sourceDrivers).first(where: { line in
            keys.contains(where: { line.localizedCaseInsensitiveContains($0) })
        }) else {
            return fallback
        }
        if let speed = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*km\/h"#, in: source) {
            return "\(speed) km/h"
        }
        if let knots = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*kt"#, in: source) {
            return "\(knots) kt"
        }
        if let metres = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*m"#, in: source) {
            return "\(metres) m"
        }
        return source
            .replacingOccurrences(of: "winds", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "wind", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "tide", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }

    private func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }

    private func visibleDriverTexts(from drivers: [String]) -> [String] {
        drivers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isPlaceholderDriverText($0) }
            .uniquePrefix(6)
    }

    private func isPlaceholderDriverText(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("pending") || lower.contains("no detailed drivers")
    }

    private func buildTideCardViewData(pageOffset: Int) -> TideCardViewData {
        let calendar = Calendar.current
        let now = Date()
        let axisStart = calendar.date(byAdding: .hour, value: pageOffset * 24, to: now) ?? now
        let axisEnd = calendar.date(byAdding: .hour, value: 24, to: axisStart) ?? axisStart
        let eventLookback = calendar.date(byAdding: .hour, value: -6, to: axisStart) ?? axisStart
        let eventLookahead = calendar.date(byAdding: .hour, value: 6, to: axisEnd) ?? axisEnd

        let authoritativeEvents = (tideForecast?.days ?? [])
            .flatMap(\.events)
            .filter { $0.time >= eventLookback && $0.time <= eventLookahead }
            .sorted { $0.time < $1.time }

        let providerSamples = (tideForecast?.days ?? [])
            .flatMap(\.samples)
            .filter { $0.time >= axisStart && $0.time <= axisEnd }
            .sorted { $0.time < $1.time }

        let chosenEvents = authoritativeEvents.map {
            TideEventViewPoint(
                time: $0.time,
                kind: $0.kind == .high ? .high : .low,
                heightMeters: $0.heightMeters,
                isDerivedHeight: $0.source == .derived
            )
        }

        let series: TideSeriesSource
        let note: String
        if !providerSamples.isEmpty {
            let points = providerSamples.map {
                TideSamplePoint(
                    time: $0.time,
                    heightMeters: $0.heightMeters,
                    isDerived: $0.source == .derived
                )
            }
            series = .sampled(points)
            note = "Official tide samples · 24h window"
        } else if !chosenEvents.isEmpty {
            let interpolationInput = chosenEvents.map {
                TideEventPoint(
                    time: $0.time,
                    kind: $0.kind == .high ? .high : .low,
                    heightMeters: $0.heightMeters ?? ($0.kind == .high ? 2.0 : 0.6),
                    source: .derived
                )
            }
            let points = TideInterpolation.buildDerivedSamples(from: interpolationInput, stepMinutes: 20).map {
                TideSamplePoint(time: $0.time, heightMeters: $0.heightMeters, isDerived: true)
            }
            series = points.isEmpty ? .unavailable : .eventInterpolated(points)
            note = "Interpolated from official tide extrema · 24h window"
        } else {
            series = .unavailable
            note = "Official tide data unavailable."
        }

        let nextHigh = chosenEvents.first(where: { $0.kind == .high && $0.time >= axisStart && $0.time <= axisEnd }) ?? chosenEvents.first(where: { $0.kind == .high && $0.time >= axisStart })
        let nextLow = chosenEvents.first(where: { $0.kind == .low && $0.time >= axisStart && $0.time <= axisEnd }) ?? chosenEvents.first(where: { $0.kind == .low && $0.time >= axisStart })
        let stateLabel = tideStateLabel(
            pageOffset: pageOffset,
            now: now,
            events: chosenEvents,
            nextHigh: nextHigh,
            nextLow: nextLow
        )
        return TideCardViewData(
            id: axisStart,
            dayLabel: tidePageLabel(for: axisStart, offset: pageOffset),
            windowLabel: tideWindowLabel(from: axisStart, to: axisEnd, offset: pageOffset),
            stateLabel: stateLabel,
            nextHigh: nextHigh,
            nextLow: nextLow,
            events: chosenEvents,
            series: series,
            axisStart: axisStart,
            axisEnd: axisEnd,
            note: tideStatusMessage ?? note
        )
    }

    private func tidePageLabel(for date: Date, offset: Int) -> String {
        Self.shortDayFormatter.string(from: date)
    }

    private func tideWindowLabel(from start: Date, to end: Date, offset: Int) -> String {
        if offset == 0 { return "Next 24h" }
        return "\(Self.shortDayFormatter.string(from: start)) \(Self.timeFormatter.string(from: start)) to \(Self.timeFormatter.string(from: end))"
    }

    private func tideStateLabel(
        pageOffset: Int,
        now: Date,
        events: [TideEventViewPoint],
        nextHigh: TideEventViewPoint?,
        nextLow: TideEventViewPoint?
    ) -> String {
        guard !events.isEmpty else { return "Official tide data unavailable" }
        if pageOffset == 0 {
            return currentTideStateLabel(now: now, events: events)
        }
        return futureTideSummary(nextHigh: nextHigh, nextLow: nextLow)
    }

    private func currentTideStateLabel(now: Date, events: [TideEventViewPoint]) -> String {
        guard let next = events.first(where: { $0.time >= now }),
              let previous = events.last(where: { $0.time < now }) else {
            return "Tide data unavailable"
        }
        if previous.kind == .low, next.kind == .high {
            return "Rising tide"
        }
        if previous.kind == .high, next.kind == .low {
            return "Falling tide"
        }
        return "Tide transitioning"
    }

    private func futureTideSummary(nextHigh: TideEventViewPoint?, nextLow: TideEventViewPoint?) -> String {
        switch (nextHigh, nextLow) {
        case let (high?, low?):
            return "Predicted high \(Self.timeFormatter.string(from: high.time)) · low \(Self.timeFormatter.string(from: low.time))"
        case let (high?, nil):
            return "Predicted high \(Self.timeFormatter.string(from: high.time))"
        case let (nil, low?):
            return "Predicted low \(Self.timeFormatter.string(from: low.time))"
        case (nil, nil):
            return "Predicted tide window"
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()
}

private struct TideStore {
    private let defaults: UserDefaults
    private let key = "cached_tide_forecast_v3"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TideForecast? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let forecast = try? JSONDecoder().decode(TideForecast.self, from: data) else { return nil }
        return forecast.provider == "estimated" ? nil : forecast
    }

    func save(_ forecast: TideForecast?) {
        guard let forecast else {
            defaults.removeObject(forKey: key)
            return
        }
        let data = try? JSONEncoder().encode(forecast)
        defaults.set(data, forKey: key)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Array where Element == String {
    func uniquePrefix(_ count: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for value in self {
            let normalized = value.lowercased()
            if seen.contains(normalized) { continue }
            seen.insert(normalized)
            out.append(value)
            if out.count >= count { break }
        }
        return out
    }
}
