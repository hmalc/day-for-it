import Foundation
import CoreLocation
import SwiftUI
import PleasantnessEngine
import WeatherCore

struct DriverMetric: Identifiable {
    let id = UUID()
    let symbol: String
    let label: String
    let value: String
    let detail: String
    let accent: Color?
}

struct NextChangeItem: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

struct ConditionRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

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

struct TideCardViewData {
    let stateLabel: String
    let nextHigh: TideEventViewPoint?
    let nextLow: TideEventViewPoint?
    let events: [TideEventViewPoint]
    let series: TideSeriesSource
    let axisStart: Date
    let axisEnd: Date
    let note: String?
}

struct FourDayOutlookItem: Identifiable {
    let id = UUID()
    let dayLabel: String
    let rating: BoatDayRating
    let scoreText: String
    let conditionSummary: String
    let hasWarning: Bool
    let isBest: Bool
}

struct FourDayDetailPage: Identifiable {
    let id = UUID()
    let dayLabel: String
    let dateText: String
    let rating: BoatDayRating
    let scoreText: String
    let availabilityText: String
    let confidenceText: String
    let warningText: String
    let topDrivers: [String]
}

struct HeroOpportunitySummary {
    let headline: String
    let subheadline: String
    let tone: BoatDayRating
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
    @Published var disclaimer = "For planning only. Always check official BOM forecasts and warnings."
    @Published var savedOverride: StoredLocation?
    @Published var tideForecast: TideForecast?
    @Published var tideStatusMessage: String?

    let locationManager: LocationManager

    private let forecastService: MarineForecastService
    private let locationStore: LocationStore
    private let tideProvider: TideDataProvider
    private let tideStore: TideStore

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
            guard self.savedOverride == nil else { return }
            Task { await self.refresh() }
        }
    }

    var hasData: Bool { output != nil }

    var currentIndex: Double {
        output?.daily[safe: selectedDayIndex]?.pleasantness ?? 0
    }

    var selectedDaySummary: DailyMarineSummary? {
        output?.daily[safe: selectedDayIndex]
    }

    var topDrivers: [String] {
        selectedDaySummary?.topDrivers ?? []
    }

    private var fourDayWindow: [DailyMarineSummary] {
        Array(displayDays.prefix(4))
    }

    var heroOpportunitySummary: HeroOpportunitySummary {
        let window = fourDayWindow
        guard !window.isEmpty else {
            return HeroOpportunitySummary(
                headline: "Checking next 4 days",
                subheadline: "Forecast loading. We will highlight the best boating window shortly.",
                tone: .amber,
                badgeText: "4-DAY LOOK",
                focusDrivers: []
            )
        }

        let ranked = window.enumerated().sorted { lhs, rhs in
            let left = lhs.element.pleasantness ?? scoreFallback(for: lhs.element.rating)
            let right = rhs.element.pleasantness ?? scoreFallback(for: rhs.element.rating)
            if left == right {
                return lhs.offset < rhs.offset
            }
            return left > right
        }
        guard let best = ranked.first else {
            return HeroOpportunitySummary(
                headline: "No clear window yet",
                subheadline: "Data is limited right now. Pull to refresh for better guidance.",
                tone: .amber,
                badgeText: "4-DAY LOOK",
                focusDrivers: []
            )
        }

        let bestDay = best.element
        let bestLabel = dayLabel(for: bestDay.dayStart, index: best.offset)
        let focusReason = conciseReason(from: bestDay.topDrivers) ?? "Window quality depends on wind, sea state, and tide timing."

        switch bestDay.rating {
        case .green:
            let headline = best.offset == 0 ? "Today looks like your best boating window" : "Best boating chance looks like \(bestLabel)"
            return HeroOpportunitySummary(
                headline: headline,
                subheadline: focusReason,
                tone: .green,
                badgeText: best.offset == 0 ? "FAVORABLE" : "LOOK TO \(bestLabel.uppercased())",
                focusDrivers: bestDay.topDrivers
            )
        case .amber:
            let headline = best.offset == 0 ? "Today can work with careful timing" : "\(bestLabel) may work if you time it right"
            return HeroOpportunitySummary(
                headline: headline,
                subheadline: "Conditions are manageable with careful timing. \(focusReason)",
                tone: .amber,
                badgeText: best.offset == 0 ? "TIME CAREFULLY" : "WATCH \(bestLabel.uppercased())",
                focusDrivers: bestDay.topDrivers
            )
        case .red:
            let blockers = window
                .flatMap(\.topDrivers)
                .compactMap { conciseReason(from: [$0]) }
                .uniquePrefix(2)
                .joined(separator: " ")
            let fallbackBlocker = blockers.isEmpty ? "Wind and sea state remain the main blockers across the period." : blockers
            return HeroOpportunitySummary(
                headline: "The next few days look challenging for boating",
                subheadline: fallbackBlocker,
                tone: .red,
                badgeText: "HOLD PLAN",
                focusDrivers: bestDay.topDrivers
            )
        }
    }

    var lastUpdatedText: String {
        guard let date = output?.generatedAt else { return "Pending" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    var heroSupportingText: String {
        heroOpportunitySummary.subheadline
    }

    var decisionSummaryText: String {
        if let llm = llmDecisionSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !llm.isEmpty {
            return llm
        }
        return heroOpportunitySummary.subheadline
    }

    var heroWindText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "wind", fallback: "Calm")
    }

    var heroWavesText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "swell", alternateKeywords: ["sea", "wave"], fallback: "Low")
    }

    var heroTideText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "tide", fallback: "Pending")
    }

    var keyDriverMetrics: [DriverMetric] {
        [
            DriverMetric(symbol: "wind", label: "Wind", value: heroWindText, detail: "Primary comfort and handling factor", accent: nil),
            DriverMetric(symbol: "water.waves", label: "Waves", value: heroWavesText, detail: "Sea state impact on ride quality", accent: Color.cyan.opacity(0.7)),
            DriverMetric(symbol: "arrow.up.and.down", label: "Tide", value: heroTideText, detail: "Windowing support for launch/return", accent: Color.teal.opacity(0.7)),
            DriverMetric(symbol: "exclamationmark.triangle.fill", label: "Warnings", value: warningBanner == nil ? "None" : "Active", detail: warningBanner == nil ? "No active marine warnings" : "Watch timing and route choices", accent: warningBanner == nil ? nil : Color.orange.opacity(0.8)),
        ]
    }

    var nextChangeItems: [NextChangeItem] {
        var items: [NextChangeItem] = []
        if let first = fourDayOutlook.first {
            items.append(NextChangeItem(symbol: "clock.arrow.circlepath", title: "Today", detail: first.conditionSummary))
        }
        if let best = fourDayOutlook.first(where: { $0.isBest }) {
            items.append(NextChangeItem(symbol: "sparkles", title: "Best day in next 4", detail: best.dayLabel == "Today" ? "Today is currently the strongest boating window." : "\(best.dayLabel) currently offers the strongest boating window."))
        }
        items.append(NextChangeItem(symbol: "wind", title: "Trend watch", detail: "Re-check before departure for updates in wind and warnings."))
        if let tide = extractDriver(keyword: "tide") {
            items.append(NextChangeItem(symbol: "arrow.up.and.down", title: "Tide update", detail: tide))
        }
        if let warningBanner {
            items.append(NextChangeItem(symbol: "exclamationmark.triangle.fill", title: "Warning in effect", detail: warningBanner))
        }
        return Array(items.prefix(5))
    }

    var tideEvents: [String] {
        let tide = tideCardViewData
        return [
            tide.nextHigh.map { "High \(Self.timeFormatter.string(from: $0.time))" } ?? "High --",
            tide.nextLow.map { "Low \(Self.timeFormatter.string(from: $0.time))" } ?? "Low --",
            tide.note ?? "Tide series unavailable",
        ]
    }

    var detailedRows: [ConditionRow] {
        [
            ConditionRow(label: "Wind", value: extractDriver(keyword: "wind") ?? heroWindText),
            ConditionRow(label: "Waves / Swell", value: extractDriver(keyword: "swell") ?? extractDriver(keyword: "wave") ?? heroWavesText),
            ConditionRow(label: "Tide basis", value: tideCardViewData.note ?? heroTideText),
            ConditionRow(label: "Rating", value: selectedDaySummary?.rating.label ?? "Unknown"),
            ConditionRow(label: "Updated", value: lastUpdatedText),
        ]
    }

    var fourDayOutlook: [FourDayOutlookItem] {
        let days = fourDayWindow
        guard !days.isEmpty else { return [] }
        let bestScore = days.compactMap(\.pleasantness).max()
        return days.enumerated().map { index, day in
            let dayLabel = dayLabel(for: day.dayStart, index: index)
            let scoreText = day.pleasantness.map { "\(Int($0.rounded()))" } ?? "--"
            let summary = conciseReason(from: day.topDrivers) ?? "Conditions update pending"
            return FourDayOutlookItem(
                dayLabel: dayLabel,
                rating: day.rating,
                scoreText: scoreText,
                conditionSummary: summary,
                hasWarning: day.warningLimited,
                isBest: day.pleasantness != nil && day.pleasantness == bestScore
            )
        }
    }

    var fourDayDetailPages: [FourDayDetailPage] {
        let days = fourDayWindow
        return days.enumerated().map { index, day in
            let dayLabel = dayLabel(for: day.dayStart, index: index)
            let dateText = Self.detailDateFormatter.string(from: day.dayStart)
            let scoreText = day.pleasantness.map { String(format: "%.0f", $0) } ?? "--"
            let availabilityText = day.availability == .available ? "Available" : "Unavailable"
            let confidenceText = day.confidence.capitalized
            let warningText = day.warningLimited ? "Warning constrained" : "No warning constraint"
            let drivers = day.topDrivers.isEmpty ? ["No detailed drivers available yet."] : day.topDrivers
            return FourDayDetailPage(
                dayLabel: dayLabel,
                dateText: dateText,
                rating: day.rating,
                scoreText: scoreText,
                availabilityText: availabilityText,
                confidenceText: confidenceText,
                warningText: warningText,
                topDrivers: Array(drivers.prefix(5))
            )
        }
    }

    var tideCardViewData: TideCardViewData {
        let day = selectedDaySummary?.dayStart ?? Calendar.current.startOfDay(for: Date())
        return buildTideCardViewData(for: day)
    }

    var tideNextHighDisplay: String {
        tideEventDisplay(prefix: "High", event: tideCardViewData.nextHigh)
    }

    var tideNextLowDisplay: String {
        tideEventDisplay(prefix: "Low", event: tideCardViewData.nextLow)
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
                pleasantness: nil,
                rating: .amber,
                availability: .unavailable,
                confidence: "low",
                warningLimited: false,
                topDrivers: []
            )
        }
    }

    func startup() {
        // Default to Cowley Beach unless user explicitly sets an override.
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        tideStatusMessage = nil
        defer { isLoading = false }

        let request = makeRequest()
        do {
            async let forecastTask = forecastService.fetchSevenDayForecast(request: request)
            async let tideTask = tideProvider.fetchTideForecast(
                location: request.location,
                start: Date(),
                days: 4,
                sampleIntervalMinutes: nil
            )

            let forecast = try await forecastTask
            output = forecast
            warningBanner = forecast.warnings.first?.title
            selectedDayIndex = 0
            errorMessage = forecast.degradedReason

            if let tide = try? await tideTask, !tide.days.isEmpty {
                tideForecast = tide
                tideStore.save(tide)
                if let station = tide.stationName {
                    if let distance = tide.stationDistanceKm, distance > 120 {
                        tideStatusMessage = "Nearest station: \(station) (\(Int(distance.rounded())) km)"
                    } else {
                        tideStatusMessage = "Station: \(station)"
                    }
                }
            } else {
                if let existing = tideForecast, !existing.days.isEmpty {
                    tideStatusMessage = "Using cached tide data."
                } else {
                    let fallback = makeEstimatedTideForecast(start: Date(), days: 4, locationName: request.location.name)
                    tideForecast = fallback
                    tideStatusMessage = "Using estimated tide model."
                }
            }
        } catch {
            let message: String
            if let urlError = error as? URLError {
                message = "Network error (\(urlError.code.rawValue)). Pull to retry."
            } else {
                message = "Could not load latest forecast (\(error.localizedDescription)). Pull to retry."
            }
            errorMessage = message
            if tideForecast == nil || tideForecast?.days.isEmpty == true {
                let fallback = makeEstimatedTideForecast(start: Date(), days: 4, locationName: request.location.name)
                tideForecast = fallback
                tideStatusMessage = "Using estimated tide model."
            } else {
                tideStatusMessage = "Using cached tide data."
            }
        }
    }

    func select(dayIndex: Int) {
        guard let output, output.daily.indices.contains(dayIndex) else { return }
        selectedDayIndex = dayIndex
    }

    func saveLocationOverride(name: String, latitude: Double, longitude: Double, timeZoneID: String = "Australia/Sydney") {
        let stored = StoredLocation(name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID)
        savedOverride = stored
        locationStore.save(stored)
        Task { await refresh() }
    }

    func clearLocationOverride() {
        savedOverride = nil
        locationStore.save(nil)
        Task { await refresh() }
    }

    func effectiveLocation() -> MarineLocation {
        if let savedOverride {
            return savedOverride.marineLocation
        }
        return DefaultLocation.cowleyBeach.location
    }

    func effectiveFeedConfig() -> MarineFeedConfig {
        if let override = savedOverride {
            let coord = CLLocationCoordinate2D(latitude: override.latitude, longitude: override.longitude)
            let nearest = CoastalPreset.nearest(to: coord)
            var feed = nearest.feed
            if nearest == .brisbane {
                feed.preferredCoastalAAC = QLDMarineZone.nearestAAC(to: coord)
            }
            return feed
        }
        return DefaultLocation.cowleyBeach.feed
    }

    private func makeRequest() -> MarineForecastRequest {
        MarineForecastRequest(
            location: effectiveLocation(),
            feed: effectiveFeedConfig(),
            forecastDays: 7
        )
    }

    private func extractDriver(keyword: String) -> String? {
        topDrivers.first(where: { $0.localizedCaseInsensitiveContains(keyword) })
    }

    private var heroFocusDrivers: [String] {
        let drivers = heroOpportunitySummary.focusDrivers
        return drivers.isEmpty ? topDrivers : drivers
    }

    private func conciseReason(from drivers: [String]) -> String? {
        guard let first = drivers.first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty else {
            return nil
        }
        if let period = first.firstIndex(of: ".") {
            return String(first[...period])
        }
        return String(first.prefix(92))
    }

    private func dayLabel(for date: Date, index: Int) -> String {
        if index == 0 { return "Today" }
        if index == 1 { return "Tomorrow" }
        return Self.dayFormatter.string(from: date)
    }

    private func scoreFallback(for rating: BoatDayRating) -> Double {
        switch rating {
        case .green:
            return 80
        case .amber:
            return 60
        case .red:
            return 35
        }
    }

    private func conciseDriverValue(keyword: String, alternateKeywords: [String] = [], fallback: String) -> String {
        conciseDriverValue(in: topDrivers, keyword: keyword, alternateKeywords: alternateKeywords, fallback: fallback)
    }

    private func conciseDriverValue(in sourceDrivers: [String], keyword: String, alternateKeywords: [String] = [], fallback: String) -> String {
        let keys = [keyword] + alternateKeywords
        guard let source = sourceDrivers.first(where: { line in
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

    private func tideEventDisplay(prefix: String, event: TideEventViewPoint?) -> String {
        guard let event else { return "\(prefix) --" }
        let time = Self.timeFormatter.string(from: event.time)
        if let height = event.heightMeters {
            return "\(prefix) \(time) · \(String(format: "%.2f m", height))"
        }
        return "\(prefix) \(time)"
    }

    private func buildTideCardViewData(for day: Date) -> TideCardViewData {
        let calendar = Calendar.current
        let now = Date()
        let axisStart = now
        let axisEnd = calendar.date(byAdding: .hour, value: 24, to: now) ?? now

        let authoritativeEvents = (tideForecast?.days ?? [])
            .flatMap(\.events)
            .filter { $0.time >= calendar.date(byAdding: .hour, value: -6, to: axisStart) ?? axisStart && $0.time <= axisEnd }
            .sorted { $0.time < $1.time }

        let providerSamples = (tideForecast?.days ?? [])
            .flatMap(\.samples)
            .filter { $0.time >= axisStart && $0.time <= axisEnd }
            .sorted { $0.time < $1.time }

        let fallbackEvents = syntheticTideEvents(for: day, anchor: now)
        let chosenEvents = authoritativeEvents.isEmpty ? fallbackEvents : authoritativeEvents.map {
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
            note = "Provider-backed tide samples · next 24h"
        } else {
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
            note = authoritativeEvents.isEmpty ? "Estimated fallback tide model · next 24h" : "Estimated between tide extrema · next 24h"
        }

        let nextHigh = chosenEvents.first(where: { $0.kind == .high && $0.time >= now }) ?? chosenEvents.first(where: { $0.kind == .high })
        let nextLow = chosenEvents.first(where: { $0.kind == .low && $0.time >= now }) ?? chosenEvents.first(where: { $0.kind == .low })
        let stateLabel = tideStateLabel(now: now, events: chosenEvents)
        return TideCardViewData(
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

    private func syntheticTideEvents(for day: Date, anchor: Date) -> [TideEventViewPoint] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let baseHeights = selectedDaySummary?.rating == .red ? (0.5, 1.9) : (0.7, 2.2)
        let offsets = [-9, -3, 3, 9, 15, 21, 27, 33]
        return offsets.enumerated().compactMap { idx, hour in
            guard let t = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                  let m = calendar.date(byAdding: .minute, value: idx.isMultiple(of: 2) ? 20 : 45, to: t) else { return nil }
            let kind: TideEventKindView = idx.isMultiple(of: 2) ? .low : .high
            let h = kind == .low ? baseHeights.0 : baseHeights.1
            return TideEventViewPoint(time: m, kind: kind, heightMeters: h, isDerivedHeight: true)
        }
        .filter { $0.time >= calendar.date(byAdding: .hour, value: -6, to: anchor) ?? anchor }
        .sorted { $0.time < $1.time }
    }

    private func interpolateSeriesFromEvents(_ events: [TideEventViewPoint], stepMinutes: Int) -> [TideSamplePoint] {
        guard events.count >= 2 else { return [] }
        var out: [TideSamplePoint] = []
        for pair in zip(events, events.dropFirst()) {
            let e0 = pair.0
            let e1 = pair.1
            guard let h0 = e0.heightMeters, let h1 = e1.heightMeters else { continue }
            let t0 = e0.time.timeIntervalSinceReferenceDate
            let t1 = e1.time.timeIntervalSinceReferenceDate
            guard t1 > t0 else { continue }
            let step = Double(stepMinutes * 60)
            var t = t0
            while t < t1 {
                let phase = max(0, min(1, (t - t0) / (t1 - t0)))
                let eased = 0.5 - 0.5 * cos(.pi * phase)
                let height = h0 + (h1 - h0) * eased
                out.append(TideSamplePoint(time: Date(timeIntervalSinceReferenceDate: t), heightMeters: height, isDerived: true))
                t += step
            }
        }
        if let last = events.last, let h = last.heightMeters {
            out.append(TideSamplePoint(time: last.time, heightMeters: h, isDerived: true))
        }
        return out
    }

    private func tideStateLabel(now: Date, events: [TideEventViewPoint]) -> String {
        guard let next = events.first(where: { $0.time >= now }),
              let previous = events.last(where: { $0.time < now }) else {
            return "Tide phase pending"
        }
        if previous.kind == .low, next.kind == .high {
            return "Rising tide"
        }
        if previous.kind == .high, next.kind == .low {
            return "Falling tide"
        }
        return "Tide transitioning"
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

    private static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()

    // Placeholder for upstream-generated summary integration.
    private var llmDecisionSummary: String? { nil }

    private func makeEstimatedTideForecast(start: Date, days: Int, locationName: String) -> TideForecast {
        let calendar = Calendar.current
        let safeDays = max(1, days)
        var dayForecasts: [TideDayForecast] = []
        for offset in 0 ..< safeDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start)) else { continue }
            let events = syntheticTideEvents(for: day, anchor: start).map {
                TideEventPoint(
                    time: $0.time,
                    kind: $0.kind == .high ? .high : .low,
                    heightMeters: $0.heightMeters,
                    source: .derived
                )
            }
            let samples = TideInterpolation.buildDerivedSamples(from: events, stepMinutes: 20)
            dayForecasts.append(TideDayForecast(dayStart: day, events: events, samples: samples))
        }
        return TideForecast(
            generatedAt: Date(),
            provider: "estimated",
            locationName: locationName,
            days: dayForecasts
        )
    }
}

private struct TideStore {
    private let defaults: UserDefaults
    private let key = "cached_tide_forecast_v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TideForecast? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TideForecast.self, from: data)
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

private enum DefaultLocation {
    case cowleyBeach

    var location: MarineLocation {
        switch self {
        case .cowleyBeach:
            return MarineLocation(
                name: "Cowley Beach",
                latitude: -17.679,
                longitude: 146.112,
                timeZoneID: "Australia/Brisbane"
            )
        }
    }

    var feed: MarineFeedConfig {
        switch self {
        case .cowleyBeach:
            var qld = CoastalPreset.brisbane.feed
            qld.preferredCoastalAAC = QLDMarineZone.nearestAAC(
                to: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            )
            return qld
        }
    }
}

private enum CoastalPreset: CaseIterable {
    case sydney
    case melbourne
    case brisbane

    var displayName: String {
        switch self {
        case .sydney: return "Sydney Coast"
        case .melbourne: return "Port Phillip Coast"
        case .brisbane: return "Moreton Bay Coast"
        }
    }

    var timeZoneID: String { "Australia/Sydney" }

    var location: MarineLocation {
        switch self {
        case .sydney:
            return MarineLocation(name: displayName, latitude: -33.86, longitude: 151.21, timeZoneID: timeZoneID)
        case .melbourne:
            return MarineLocation(name: displayName, latitude: -37.81, longitude: 144.96, timeZoneID: timeZoneID)
        case .brisbane:
            return MarineLocation(name: displayName, latitude: -27.47, longitude: 153.03, timeZoneID: timeZoneID)
        }
    }

    var feed: MarineFeedConfig {
        switch self {
        case .sydney:
            return MarineFeedConfig(
                coastalProductID: "IDN11001",
                observationProductID: "IDN60901",
                observationStationWMO: 94767,
                marineWarningRSSPath: "/fwo/IDZ00068.warnings_marine_nsw.xml",
                preferredCoastalAAC: "NSW_MW004"
            )
        case .melbourne:
            return MarineFeedConfig(
                coastalProductID: "IDV10753",
                observationProductID: "IDV60901",
                observationStationWMO: 95936,
                marineWarningRSSPath: "/fwo/IDZ00073.warnings_marine_vic.xml",
                preferredCoastalAAC: nil
            )
        case .brisbane:
            return MarineFeedConfig(
                coastalProductID: "IDQ11290",
                observationProductID: "IDQ60901",
                observationStationWMO: 94576,
                marineWarningRSSPath: "/fwo/IDZ00070.warnings_marine_qld.xml",
                preferredCoastalAAC: nil
            )
        }
    }

    static func nearest(to coord: CLLocationCoordinate2D) -> CoastalPreset {
        allCases.min(by: { lhs, rhs in
            let d1 = hypot(lhs.location.latitude - coord.latitude, lhs.location.longitude - coord.longitude)
            let d2 = hypot(rhs.location.latitude - coord.latitude, rhs.location.longitude - coord.longitude)
            return d1 < d2
        }) ?? .sydney
    }
}

private struct QLDMarineZone {
    let aac: String
    let latitude: Double
    let longitude: Double

    static let all: [QLDMarineZone] = [
        .init(aac: "QLD_MW001", latitude: -15.5, longitude: 141.6),
        .init(aac: "QLD_MW002", latitude: -12.4, longitude: 142.8),
        .init(aac: "QLD_MW003", latitude: -10.7, longitude: 142.2),
        .init(aac: "QLD_MW004", latitude: -13.2, longitude: 143.8),
        .init(aac: "QLD_MW005", latitude: -14.8, longitude: 145.0),
        .init(aac: "QLD_MW006", latitude: -16.5, longitude: 145.8),
        .init(aac: "QLD_MW007", latitude: -18.7, longitude: 146.6),
        .init(aac: "QLD_MW008", latitude: -20.7, longitude: 149.2),
        .init(aac: "QLD_MW009", latitude: -23.6, longitude: 151.2),
        .init(aac: "QLD_MW010", latitude: -25.2, longitude: 152.9),
        .init(aac: "QLD_MW011", latitude: -25.8, longitude: 153.2),
        .init(aac: "QLD_MW012", latitude: -26.6, longitude: 153.1),
        .init(aac: "QLD_MW013", latitude: -27.3, longitude: 153.2),
        .init(aac: "QLD_MW014", latitude: -28.1, longitude: 153.5),
        .init(aac: "QLD_MW015", latitude: -19.5, longitude: 149.8),
    ]

    static func nearestAAC(to coord: CLLocationCoordinate2D) -> String {
        all.min(by: { lhs, rhs in
            let d1 = hypot(lhs.latitude - coord.latitude, lhs.longitude - coord.longitude)
            let d2 = hypot(rhs.latitude - coord.latitude, rhs.longitude - coord.longitude)
            return d1 < d2
        })?.aac ?? "QLD_MW013"
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

// MARK: - Inline support types
// Kept in this file so app builds even if project sources list is stale.

struct StoredLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String

    var marineLocation: MarineLocation {
        MarineLocation(name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID)
    }
}

struct LocationStore {
    private let defaults: UserDefaults
    private let key = "saved_location_override_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredLocation? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredLocation.self, from: data)
    }

    func save(_ location: StoredLocation?) {
        guard let location else {
            defaults.removeObject(forKey: key)
            return
        }
        let data = try? JSONEncoder().encode(location)
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentCoordinate: CLLocationCoordinate2D?
    var onCoordinateUpdate: ((CLLocationCoordinate2D) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func refreshLocation() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }
}

@MainActor extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentCoordinate = locations.last?.coordinate
        if let coordinate = currentCoordinate {
            onCoordinateUpdate?(coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        _ = error
    }
}
