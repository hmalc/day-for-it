import Foundation
import CoreLocation
import SwiftUI
import PleasantnessEngine
import WeatherCore

#if canImport(FoundationModels)
import FoundationModels
#endif

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
    let chartMaximumMeters: Double
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
    let sourceIndex: Int
    let dayLabel: String
    let dateText: String
    let rating: BoatDayRating
    let scoreValue: Double?
    let scoreText: String
    let summaryText: String
    let confidenceText: String
    let evidenceText: String
    let contextText: String?
    let warningText: String
    let topDrivers: [String]
    let isBest: Bool
}

struct HeroOpportunitySummary {
    let headline: String
    let subheadline: String
    let tone: BoatDayRating
    let badgeText: String
    let focusDrivers: [String]
}

struct MarineEvidenceStatus {
    let title: String
    let detail: String
    let valueText: String
    let isConfirmed: Bool
}

struct DecisionCopy: Sendable, Equatable {
    let headline: String?
    let summary: String?
}

struct DecisionSummaryContext: Sendable, Equatable {
    let locationName: String
    let headline: String
    let fallbackSummary: String
    let windowText: String?
    let scoreText: String?
    let decisionLabel: String?
    let verdict: String?
    let marineEvidenceTitle: String
    let marineEvidenceDetail: String
    let windText: String
    let wavesText: String
    let tideText: String
    let tideEvents: [String]
    let warningText: String?
    let confidence: String?
    let priority: String?
    let reasons: [String]
    let riskFlags: [String]
    let dataSignals: [String]
    let sourceStatus: [String]
    let forecastDays: [String]
    let topDrivers: [String]
}

struct DecisionSummaryGenerator {
    func generate(context: DecisionSummaryContext) async -> DecisionCopy? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { return nil }

            let session = LanguageModelSession(
                model: model,
                instructions: """
                You write tiny boating guidance copy for Day For It.
                Use only the supplied facts. Do not invent conditions.
                Be conservative: boating is never guaranteed safe.
                The headline is the main glanceable answer.
                The summary is one calm sentence under 30 words.
                If wave height or swell data is not available, say so clearly.
                Use "Day for it" only when wave height or swell forecast data confirms the call.
                Include useful tide timing when tide highs and lows are supplied.
                Do not mention being an AI, scores, JSON, or internal models.
                Return exactly two lines:
                Headline: <short headline>
                Summary: <short summary>
                """
            )

            let response = try? await session.respond(
                to: prompt(for: context),
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.2,
                    maximumResponseTokens: 70
                )
            )

            return Self.parseCopy(response?.content)
        }
        #endif

        return nil
    }

    private func prompt(for context: DecisionSummaryContext) -> String {
        var lines = [
            "Location: \(context.locationName)",
            "Fallback headline: \(context.headline)",
            "Fallback summary: \(context.fallbackSummary)",
            "Wave/swell evidence: \(context.marineEvidenceTitle). \(context.marineEvidenceDetail)",
            "Wind: \(context.windText)",
            "Sea/waves: \(context.wavesText)",
            "Tide: \(context.tideText)"
        ]

        if let windowText = context.windowText {
            lines.append("Best window: \(windowText)")
        }
        if let scoreText = context.scoreText {
            lines.append("Score: \(scoreText)")
        }
        if let decisionLabel = context.decisionLabel {
            lines.append("Decision label: \(decisionLabel)")
        }
        if let verdict = context.verdict {
            lines.append("Verdict: \(verdict)")
        }
        if let confidence = context.confidence {
            lines.append("Confidence: \(confidence)")
        }
        if let priority = context.priority {
            lines.append("Priority: \(priority)")
        }
        if let warningText = context.warningText {
            lines.append("Warning: \(warningText)")
        }
        if !context.tideEvents.isEmpty {
            lines.append("All tide events: \(context.tideEvents.prefix(6).joined(separator: " | "))")
        }
        if !context.reasons.isEmpty {
            lines.append("Reasons: \(context.reasons.prefix(5).joined(separator: " | "))")
        }
        if !context.riskFlags.isEmpty {
            lines.append("Risk flags: \(context.riskFlags.prefix(4).joined(separator: " | "))")
        }
        if !context.dataSignals.isEmpty {
            lines.append("Provider signals: \(context.dataSignals.prefix(6).joined(separator: " | "))")
        }
        if !context.sourceStatus.isEmpty {
            lines.append("Source status: \(context.sourceStatus.prefix(5).joined(separator: " | "))")
        }
        if !context.forecastDays.isEmpty {
            lines.append("Forecast days: \(context.forecastDays.prefix(7).joined(separator: " | "))")
        }
        if !context.topDrivers.isEmpty {
            lines.append("Drivers: \(context.topDrivers.prefix(6).joined(separator: " | "))")
        }

        lines.append("Write the two output lines now.")
        return lines.joined(separator: "\n")
    }

    static func parseCopy(_ value: String?) -> DecisionCopy? {
        guard let value else { return nil }
        var headline: String?
        var summary: String?

        for rawLine in value.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = line.lowercased()
            if lower.hasPrefix("headline:") {
                headline = cleanedLine(String(line.dropFirst("headline:".count)), maxCharacters: 42)
            } else if lower.hasPrefix("summary:") {
                summary = cleanedLine(String(line.dropFirst("summary:".count)), maxCharacters: 170)
            }
        }

        if headline == nil, summary == nil {
            summary = cleanedLine(value, maxCharacters: 170)
        }

        guard headline != nil || summary != nil else { return nil }
        return DecisionCopy(headline: headline, summary: summary)
    }

    private static func cleanedLine(_ value: String?, maxCharacters: Int) -> String? {
        guard var text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        text = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"^["“]|["”]$"#, with: "", options: .regularExpression)

        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        if text.count > maxCharacters {
            text = String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text.isEmpty ? nil : text
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDayIndex = 0
    @Published var output: MarineForecastOutput?
    @Published var warningBanner: String?
    @Published var disclaimer = "For planning only. Uses Bureau marine data Australia-wide where configured, Queensland Government tide and wave data where available, and backend boating-window analysis as a secondary planning signal."
    @Published var savedOverride: StoredLocation?
    @Published var tideForecast: TideForecast?
    @Published var tideStatusMessage: String?
    @Published var isLoadingOpportunities = false
    @Published var opportunityErrorMessage: String?
    @Published var opportunityRecommendations: [OpportunityRecommendation] = []
    @Published var opportunityAttribution: String?
    @Published var opportunityFetchedAt: Date?
    @Published var selectedOpportunityInterestIDs = Set(OpportunityActivity.clientAnchorIDs)
    @Published var opportunityFeedback: [String: String] = [:]
    @Published private(set) var llmDecisionHeadline: String?
    @Published private(set) var llmDecisionSummary: String?
    @Published private(set) var isGeneratingDecisionSummary = false
    @Published var highConfidenceBoatingAlertsEnabled: Bool
    @Published private(set) var boatingAlertAuthorizationText = "Checking"
    @Published private(set) var boatingAlertLastCheckText: String?
    @Published private(set) var boatingAlertLastResultText: String?

    let locationManager: LocationManager

    private let forecastService: MarineForecastService
    private let opportunityClient: OpportunityClientProtocol
    private let decisionSummaryGenerator: DecisionSummaryGenerator
    private let opportunityClientIDStore: OpportunityClientIDStore
    private let boatingAlertService: BoatingAlertService
    private let locationStore: LocationStore
    private let tideProvider: TideDataProvider
    private let tideStore: TideStore
    private var pendingCurrentLocationSelection = false
    private var refreshGeneration = 0
    private var opportunityRefreshGeneration = 0
    private var decisionSummaryGeneration = 0

    init(
        locationManager: LocationManager = .init(),
        forecastService: MarineForecastService = .init(),
        opportunityClient: OpportunityClientProtocol = OpportunityClient(),
        decisionSummaryGenerator: DecisionSummaryGenerator = .init(),
        opportunityClientIDStore: OpportunityClientIDStore = .init(),
        boatingAlertService: BoatingAlertService? = nil,
        locationStore: LocationStore = .init(),
        tideProvider: TideDataProvider = QueenslandTideDataProvider()
    ) {
        self.locationManager = locationManager
        self.forecastService = forecastService
        self.opportunityClient = opportunityClient
        self.decisionSummaryGenerator = decisionSummaryGenerator
        self.opportunityClientIDStore = opportunityClientIDStore
        let resolvedAlertService = boatingAlertService ?? BoatingAlertService(
            opportunityClient: opportunityClient,
            clientIDStore: opportunityClientIDStore
        )
        self.boatingAlertService = resolvedAlertService
        self.highConfidenceBoatingAlertsEnabled = resolvedAlertService.alertsEnabled
        self.boatingAlertLastCheckText = resolvedAlertService.lastCheckDate.map {
            Self.relativeDateFormatter.localizedString(for: $0, relativeTo: Date())
        }
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

    var currentIndex: Double {
        output?.daily[safe: selectedDayIndex]?.pleasantness ?? 0
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

    private var fourDayWindow: [DailyMarineSummary] {
        forecastDisplayWindow.map(\.day)
    }

    private var forecastDisplayWindow: [(sourceIndex: Int, day: DailyMarineSummary)] {
        let indexedDays = Array(displayDays.enumerated()).map { (sourceIndex: $0.offset, day: $0.element) }
        let displayHorizon = Array(indexedDays.prefix(Self.localForecastDisplayDays))
        let available = displayHorizon.filter { item in
            item.day.availability == .available || item.day.pleasantness != nil
        }
        return available.isEmpty ? displayHorizon : available
    }

    var heroOpportunitySummary: HeroOpportunitySummary {
        if let recommendation = backendBoatingRecommendation {
            return backendHeroOpportunitySummary(for: recommendation)
        }

        let window = fourDayWindow
        guard !window.isEmpty else {
            return HeroOpportunitySummary(
                headline: "Checking the ocean",
                subheadline: "Forecast loading.",
                tone: .amber,
                badgeText: "CHECKING",
                focusDrivers: []
            )
        }

        let usable = window.enumerated().filter { _, day in
            day.rating == .green || day.rating == .amber
        }
        let easy = usable.filter { _, day in day.rating == .green }
        let careful = usable.filter { _, day in day.rating == .amber }
        let rankedUsable = usable.sorted { lhs, rhs in
            let left = lhs.element.pleasantness ?? scoreFallback(for: lhs.element.rating)
            let right = rhs.element.pleasantness ?? scoreFallback(for: rhs.element.rating)
            if left == right {
                return lhs.offset < rhs.offset
            }
            return left > right
        }
        let rankedAll = window.enumerated().sorted { lhs, rhs in
            let left = lhs.element.pleasantness ?? scoreFallback(for: lhs.element.rating)
            let right = rhs.element.pleasantness ?? scoreFallback(for: rhs.element.rating)
            if left == right {
                return lhs.offset < rhs.offset
            }
            return left > right
        }

        guard let leadWindow = rankedUsable.first ?? rankedAll.first else {
            return HeroOpportunitySummary(
                headline: "No clear ocean window yet",
                subheadline: "Data is limited right now. Pull to refresh for better guidance.",
                tone: .amber,
                badgeText: "CHECKING",
                focusDrivers: []
            )
        }

        let leadDay = leadWindow.element
        let usableLabels = usable
            .prefix(3)
            .map { dayLabel(for: $0.element.dayStart, index: $0.offset) }
        let focusReason = conciseReason(from: leadDay.topDrivers) ?? "Window quality depends on wind, sea state, and tide timing."

        if !easy.isEmpty {
            let headline: String
            if usableLabels.count == 1 {
                headline = "Go: \(usableLabels[0])"
            } else {
                headline = "Go: \(usableLabels.joined(separator: ", "))"
            }
            return HeroOpportunitySummary(
                headline: headline,
                subheadline: focusReason,
                tone: .green,
                badgeText: "GO",
                focusDrivers: leadDay.topDrivers
            )
        }

        if !careful.isEmpty {
            let headline: String
            if usableLabels.count == 1 {
                headline = "Maybe: \(usableLabels[0])"
            } else {
                headline = "Maybe: \(usableLabels.joined(separator: ", "))"
            }
            return HeroOpportunitySummary(
                headline: headline,
                subheadline: focusReason,
                tone: .amber,
                badgeText: "MAYBE",
                focusDrivers: leadDay.topDrivers
            )
        }

        let blockers = window
            .flatMap(\.topDrivers)
            .compactMap { conciseReason(from: [$0]) }
            .uniquePrefix(2)
            .joined(separator: " ")
        let fallbackBlocker = blockers.isEmpty ? "Wind and sea state remain the main blockers across the period." : blockers
        return HeroOpportunitySummary(
            headline: "Hold off offshore",
            subheadline: fallbackBlocker,
            tone: .red,
            badgeText: "HOLD",
            focusDrivers: leadDay.topDrivers
        )
    }

    var lastUpdatedText: String? {
        guard let date = output?.generatedAt else { return nil }
        if abs(date.timeIntervalSinceNow) < 45 {
            return "Just now"
        }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    var opportunityUpdatedText: String? {
        guard let date = opportunityFetchedAt else { return nil }
        if abs(date.timeIntervalSinceNow) < 45 {
            return "Just now"
        }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    var topOpportunity: OpportunityRecommendation? {
        opportunityRecommendations.first
    }

    var backendBoatingRecommendation: OpportunityRecommendation? {
        opportunityRecommendation(for: "boating")
    }

    func opportunityRecommendation(for activityID: String) -> OpportunityRecommendation? {
        opportunityRecommendations.first { $0.activity == activityID }
    }

    var heroSupportingText: String {
        heroOpportunitySummary.subheadline
    }

    var decisionHeadlineText: String {
        if let llm = llmDecisionHeadline?.trimmingCharacters(in: .whitespacesAndNewlines), !llm.isEmpty {
            return llm
        }
        return heroOpportunitySummary.headline
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
        if let recommendation = backendBoatingRecommendation, !recommendationHasKnownSeaData(recommendation) {
            return "Not confirmed"
        }
        return conciseDriverValue(in: heroFocusDrivers, keyword: "swell", alternateKeywords: ["sea", "wave"], fallback: "Low")
    }

    var heroTideText: String {
        conciseDriverValue(in: heroFocusDrivers, keyword: "tide", fallback: "No tide signal")
    }

    var marineEvidenceStatus: MarineEvidenceStatus {
        if let recommendation = backendBoatingRecommendation {
            return marineEvidenceStatus(for: recommendation)
        }

        if let detail = localKnownSeaDetail() {
            return MarineEvidenceStatus(
                title: "Wave + swell data",
                detail: detail,
                valueText: heroWavesText,
                isConfirmed: true
            )
        }

        return MarineEvidenceStatus(
            title: "Wave/swell missing",
            detail: "Wind can flag a possible window, but the call needs wave height and swell data.",
            valueText: "Awaiting waves",
            isConfirmed: false
        )
    }

    var keyDriverMetrics: [DriverMetric] {
        let evidence = marineEvidenceStatus
        return [
            DriverMetric(symbol: "water.waves", label: "Sea / swell", value: evidence.valueText, detail: evidence.isConfirmed ? "Primary ride-quality signal" : "Required before a strong call", accent: DayForItPalette.oceanDeep.opacity(0.7)),
            DriverMetric(symbol: "wind", label: "Wind", value: heroWindText, detail: evidence.isConfirmed ? "Supplementary trend signal" : "Forward-looking candidate signal", accent: nil),
            DriverMetric(symbol: "arrow.up.and.down", label: "Tide", value: heroTideText, detail: "Windowing support for launch/return", accent: DayForItPalette.okay.opacity(0.7)),
            DriverMetric(symbol: "exclamationmark.triangle.fill", label: "Warnings", value: warningBanner == nil ? "None" : "Active", detail: warningBanner == nil ? "No active marine warnings" : "Watch timing and route choices", accent: warningBanner == nil ? nil : DayForItPalette.hold.opacity(0.8)),
        ]
    }

    var nextChangeItems: [NextChangeItem] {
        var items: [NextChangeItem] = []
        if let first = fourDayOutlook.first {
            items.append(NextChangeItem(symbol: "clock.arrow.circlepath", title: "Today", detail: first.conditionSummary))
        }
        if let best = fourDayOutlook.first(where: { $0.isBest }) {
            items.append(NextChangeItem(symbol: "sparkles", title: "Cleanest window", detail: best.dayLabel == "Today" ? "Today is currently the cleanest ocean window." : "\(best.dayLabel) is currently the cleanest ocean window."))
        }
        items.append(NextChangeItem(symbol: "wind", title: "Trend watch", detail: "Wind can flag candidates; wave height and swell need to confirm the call."))
        if let tide = extractDriver(keyword: "tide") {
            items.append(NextChangeItem(symbol: "arrow.up.and.down", title: "Tide update", detail: tide))
        }
        if let warningBanner {
            items.append(NextChangeItem(symbol: "exclamationmark.triangle.fill", title: "Warning in effect", detail: warningBanner))
        }
        return Array(items.prefix(5))
    }

    var tideEvents: [String] {
        let events = tideEventsInDisplayWindow(for: tideCardViewData)
            .map(tideEventSummary)
        return events.isEmpty ? ["Tide series unavailable"] : events
    }

    var detailedRows: [ConditionRow] {
        var rows = [
            ConditionRow(label: "Sea data", value: "\(marineEvidenceStatus.title): \(marineEvidenceStatus.detail)"),
            ConditionRow(label: "Waves / Swell", value: extractDriver(keyword: "swell") ?? extractDriver(keyword: "wave") ?? heroWavesText),
            ConditionRow(label: "Wind", value: extractDriver(keyword: "wind") ?? heroWindText),
            ConditionRow(label: "Tide basis", value: tideCardViewData.note ?? heroTideText),
            ConditionRow(label: "Rating", value: selectedDaySummary?.rating.label ?? "Unknown"),
        ]
        if let lastUpdatedText {
            rows.append(ConditionRow(label: "Updated", value: lastUpdatedText))
        }
        return rows
    }

    var fourDayOutlook: [FourDayOutlookItem] {
        let days = fourDayWindow
        guard !days.isEmpty else { return [] }
        let bestScore = days.compactMap(\.pleasantness).max()
        return days.enumerated().map { index, day in
            let dayLabel = dayLabel(for: day.dayStart, index: index)
            let scoreText = day.pleasantness.map { "\(Int($0.rounded()))" } ?? "--"
            let summary = conciseReason(from: day.topDrivers) ?? "Forecast details unavailable"
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
        let days = forecastDisplayWindow
        let bestScore = days.compactMap { $0.day.pleasantness }.max()
        return days.enumerated().map { displayIndex, item in
            let day = item.day
            let isBest = day.pleasantness != nil && day.pleasantness == bestScore
            let dayLabel = dayLabel(for: day.dayStart, index: displayIndex)
            let dateText = Self.detailDateFormatter.string(from: day.dayStart)
            let scoreText = day.pleasantness.map { String(format: "%.0f", $0) } ?? "--"
            let drivers = visibleDriverTexts(from: day.topDrivers)
            let summaryText = conciseReason(from: drivers) ?? "Forecast details unavailable"
            let confidenceText = day.confidence.capitalized
            let evidenceText = forecastEvidenceLabel(for: day)
            let contextText = forecastContextText(for: day, isBest: isBest)
            let warningText = day.warningLimited ? "Warning active" : "No warnings"
            return FourDayDetailPage(
                sourceIndex: item.sourceIndex,
                dayLabel: dayLabel,
                dateText: dateText,
                rating: day.rating,
                scoreValue: day.pleasantness,
                scoreText: scoreText,
                summaryText: summaryText,
                confidenceText: confidenceText,
                evidenceText: evidenceText,
                contextText: contextText,
                warningText: warningText,
                topDrivers: drivers,
                isBest: isBest
            )
        }
    }

    var tideCardViewData: TideCardViewData {
        tidePageViewData.first ?? buildTideCardViewData(pageOffset: 0)
    }

    var tidePageViewData: [TideCardViewData] {
        (0 ..< 4).map { buildTideCardViewData(pageOffset: $0) }
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
        return (0 ..< Self.localForecastDisplayDays).compactMap { offset in
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
        Task { await refreshHomeData(clearsExistingData: false, allowsCachedTideFallback: true, forcesNetworkReload: false) }
        Task { await prepareBoatingAlertsForStartup() }
    }

    func refresh() async {
        await refreshHomeData(
            clearsExistingData: true,
            allowsCachedTideFallback: false,
            forcesNetworkReload: true,
            preservesOpportunityState: true
        )
    }

    func refreshHome() async {
        await refreshHomeData(
            clearsExistingData: true,
            allowsCachedTideFallback: false,
            forcesNetworkReload: true,
            preservesOpportunityState: true
        )
    }

    private func refreshHomeData(
        clearsExistingData: Bool,
        allowsCachedTideFallback: Bool,
        forcesNetworkReload: Bool,
        preservesOpportunityState: Bool = false
    ) async {
        if forcesNetworkReload {
            prepareForHardHomeRefresh(preservesOpportunityState: preservesOpportunityState)
        }
        await refreshFullData(
            clearsExistingData: clearsExistingData && !forcesNetworkReload,
            allowsCachedTideFallback: allowsCachedTideFallback
        )
        await refreshOpportunities(clearsExistingData: false)
        await refreshDecisionSummary()
    }

    func loadOpportunitiesIfNeeded() async {
        guard opportunityRecommendations.isEmpty else { return }
        await refreshOpportunities(clearsExistingData: false)
        await refreshDecisionSummary()
    }

    func refreshOpportunities(clearsExistingData: Bool = false) async {
        opportunityRefreshGeneration += 1
        let generation = opportunityRefreshGeneration
        isLoadingOpportunities = true
        opportunityErrorMessage = nil
        if clearsExistingData {
            clearOpportunityData(clearFeedback: false)
        }
        defer {
            if generation == opportunityRefreshGeneration {
                isLoadingOpportunities = false
            }
        }

        let location = effectiveLocation()
        let interests = OpportunityActivity.all
            .map(\.id)
            .filter { selectedOpportunityInterestIDs.contains($0) }

        do {
            let response = try await opportunityClient.scan(
                location: location,
                clientID: opportunityClientIDStore.loadOrCreate(),
                interests: interests.isEmpty ? OpportunityActivity.clientAnchorIDs : interests
            )
            guard generation == opportunityRefreshGeneration else { return }
            opportunityRecommendations = response.recommendations.filter(isDisplayableOpportunityRecommendation)
            opportunityAttribution = response.attribution
            opportunityFetchedAt = response.fetchedAt
            llmDecisionHeadline = nil
            llmDecisionSummary = nil
        } catch {
            guard generation == opportunityRefreshGeneration else { return }
            llmDecisionHeadline = nil
            llmDecisionSummary = nil
            if let urlError = error as? URLError {
                opportunityErrorMessage = "Could not scan opportunities (\(urlError.code.rawValue)). Pull to retry."
            } else {
                opportunityErrorMessage = "Could not scan opportunities. Pull to retry."
            }
        }
    }

    func toggleOpportunityInterest(_ id: String) {
        if selectedOpportunityInterestIDs.contains(id) {
            selectedOpportunityInterestIDs.remove(id)
        } else {
            selectedOpportunityInterestIDs.insert(id)
        }
        Task {
            await refreshOpportunities(clearsExistingData: true)
            await refreshDecisionSummary()
        }
    }

    func submitOpportunityFeedback(recommendation: OpportunityRecommendation, feedback: OpportunityFeedback, label: String) {
        opportunityFeedback[recommendation.id] = label
        Task {
            do {
                try await opportunityClient.submitFeedback(
                    recommendationID: recommendation.id,
                    clientID: opportunityClientIDStore.loadOrCreate(),
                    feedback: feedback
                )
            } catch {
                await MainActor.run {
                    opportunityFeedback[recommendation.id] = nil
                    opportunityErrorMessage = "Could not save feedback. Try again."
                }
            }
        }
    }

    func setHighConfidenceBoatingAlertsEnabled(_ enabled: Bool) {
        highConfidenceBoatingAlertsEnabled = enabled
        boatingAlertService.setAlertsEnabled(enabled)
        if enabled {
            Task {
                await prepareBoatingAlertsForStartup()
                await runBoatingAlertCheckNow()
            }
        } else {
            boatingAlertLastResultText = "Alerts are off."
        }
    }

    func runBoatingAlertCheckNow() async {
        let result = await boatingAlertService.checkForAlert(location: effectiveLocation(), canRequestAuthorization: true)
        boatingAlertLastResultText = result.message
        await refreshBoatingAlertStatus()
        scheduleBoatingAlertRefreshIfNeeded()
    }

    func handleBoatingAlertBackgroundTask() async {
        let result = await boatingAlertService.checkForAlert(location: effectiveLocation(), canRequestAuthorization: false)
        boatingAlertLastResultText = result.message
        await refreshBoatingAlertStatus()
        scheduleBoatingAlertRefreshIfNeeded()
    }

    func scheduleBoatingAlertRefreshIfNeeded() {
        if highConfidenceBoatingAlertsEnabled {
            BoatingAlertScheduler.scheduleNextCheck()
        } else {
            BoatingAlertScheduler.cancelScheduledChecks()
        }
    }

    private func prepareBoatingAlertsForStartup() async {
        highConfidenceBoatingAlertsEnabled = boatingAlertService.alertsEnabled
        if highConfidenceBoatingAlertsEnabled {
            _ = await boatingAlertService.requestAuthorizationIfNeeded()
            scheduleBoatingAlertRefreshIfNeeded()
        }
        await refreshBoatingAlertStatus()
    }

    private func refreshBoatingAlertStatus() async {
        boatingAlertAuthorizationText = await boatingAlertService.authorizationText()
        boatingAlertLastCheckText = boatingAlertService.lastCheckDate.map {
            Self.relativeDateFormatter.localizedString(for: $0, relativeTo: Date())
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
            async let forecastTask = forecastService.fetchForecast(request: request)
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
            warningBanner = forecast.daily.prefix(Self.localForecastDisplayDays).contains(where: \.warningLimited) ? forecast.warnings.first?.title : nil
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
        if let savedOverride {
            return savedOverride.marineLocation
        }
        return DefaultLocation.cowleyBeach.location
    }

    func effectiveFeedConfig() -> MarineFeedConfig {
        let location = effectiveLocation()
        let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        if isQueenslandCoordinate(coord) {
            return queenslandFeed(for: coord)
        }

        if
            let nearest = LocationPreset.nearestForecastOnly(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            let feed = nearest.feed
        {
            return feed
        }

        return CoastalPreset.brisbane.feed
    }

    private func makeRequest() -> MarineForecastRequest {
        MarineForecastRequest(
            location: effectiveLocation(),
            feed: effectiveFeedConfig(),
            forecastDays: Self.localForecastRequestDays
        )
    }

    private func isQueenslandCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        let insideBroadQueenslandBounds = (-29.5 ... -9.0).contains(coord.latitude) && (137.5 ... 154.5).contains(coord.longitude)
        let southOfCoastalBorder = coord.latitude < -28.25 && coord.longitude > 151.0
        return insideBroadQueenslandBounds && !southOfCoastalBorder
    }

    func supportsManualLocation(latitude: Double, longitude: Double) -> Bool {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return isQueenslandCoordinate(coord) || LocationPreset.nearestForecastOnly(
            latitude: latitude,
            longitude: longitude
        ) != nil
    }

    private func queenslandFeed(for coord: CLLocationCoordinate2D) -> MarineFeedConfig {
        var feed = CoastalPreset.brisbane.feed
        feed.preferredCoastalAAC = QLDMarineZone.nearestAAC(to: coord)
        if let observationStation = QLDObservationStation.nearest(to: coord) {
            feed.observationProductID = observationStation.productID
            feed.observationStationWMO = observationStation.wmo
        }
        return feed
    }

    private func applyCurrentLocationIfAvailable() {
        guard let coordinate = locationManager.currentCoordinate else { return }
        guard supportsManualLocation(latitude: coordinate.latitude, longitude: coordinate.longitude) else {
            pendingCurrentLocationSelection = false
            errorMessage = "Current location is outside the supported Australian coastal coverage areas."
            return
        }
        let timeZoneID = isQueenslandCoordinate(coordinate)
            ? "Australia/Brisbane"
            : LocationPreset.nearestForecastOnly(latitude: coordinate.latitude, longitude: coordinate.longitude)?.timeZoneID ?? "Australia/Sydney"
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
        prepareForHardHomeRefresh(preservesOpportunityState: false)
        Task {
            await refreshFullData(clearsExistingData: false, allowsCachedTideFallback: false)
            await refreshOpportunities(clearsExistingData: false)
            await refreshDecisionSummary()
        }
    }

    private func prepareForHardHomeRefresh(preservesOpportunityState: Bool) {
        refreshGeneration += 1
        opportunityRefreshGeneration += 1
        decisionSummaryGeneration += 1
        URLCache.shared.removeAllCachedResponses()

        isLoading = true
        isLoadingOpportunities = true
        isGeneratingDecisionSummary = false
        errorMessage = nil
        opportunityErrorMessage = nil
        tideStatusMessage = nil

        clearDisplayedData(clearStoredTide: true)
        if !preservesOpportunityState {
            clearOpportunityData(clearFeedback: true)
        }
    }

    private func clearDisplayedData(clearStoredTide: Bool) {
        output = nil
        tideForecast = nil
        warningBanner = nil
        tideStatusMessage = nil
        selectedDayIndex = 0
        decisionSummaryGeneration += 1
        llmDecisionHeadline = nil
        llmDecisionSummary = nil
        isGeneratingDecisionSummary = false
        if clearStoredTide {
            tideStore.save(nil)
        }
    }

    private func clearOpportunityData(clearFeedback: Bool) {
        opportunityRecommendations = []
        opportunityFetchedAt = nil
        opportunityAttribution = nil
        decisionSummaryGeneration += 1
        llmDecisionHeadline = nil
        llmDecisionSummary = nil
        isGeneratingDecisionSummary = false
        if clearFeedback {
            opportunityFeedback = [:]
        }
    }

    private func refreshDecisionSummary() async {
        decisionSummaryGeneration += 1
        let generation = decisionSummaryGeneration
        llmDecisionHeadline = nil
        llmDecisionSummary = nil

        guard let context = makeDecisionSummaryContext() else {
            isGeneratingDecisionSummary = false
            return
        }

        isGeneratingDecisionSummary = true
        let generated = await decisionSummaryGenerator.generate(context: context)
        guard generation == decisionSummaryGeneration else { return }

        llmDecisionHeadline = generated?.headline
        llmDecisionSummary = generated?.summary
        isGeneratingDecisionSummary = false
    }

    private func makeDecisionSummaryContext() -> DecisionSummaryContext? {
        let summary = heroOpportunitySummary
        let fallback = summary.subheadline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.headline.isEmpty || !fallback.isEmpty else { return nil }

        let recommendation = backendBoatingRecommendation
        let evidence = marineEvidenceStatus
        let tideEvents = tideEventsForDecision(recommendation: recommendation)
        return DecisionSummaryContext(
            locationName: activeLocationName,
            headline: summary.headline,
            fallbackSummary: fallback,
            windowText: recommendation.map { opportunityWindowText(for: $0.window) },
            scoreText: recommendation.map { "\(Int($0.finalScore.rounded()))/100" },
            decisionLabel: recommendation?.analysis?.band ?? recommendation?.decisionLabel,
            verdict: recommendation?.verdict,
            marineEvidenceTitle: evidence.title,
            marineEvidenceDetail: evidence.detail,
            windText: heroWindText,
            wavesText: heroWavesText,
            tideText: tideSummaryForDecision(recommendation: recommendation),
            tideEvents: tideEvents,
            warningText: warningBanner,
            confidence: recommendation?.confidence,
            priority: recommendation?.priority,
            reasons: recommendation?.reasons ?? [],
            riskFlags: recommendation?.riskFlags ?? [],
            dataSignals: recommendation?.analysis?.dataSignals ?? [],
            sourceStatus: recommendation?.analysis?.sourceStatus ?? [],
            forecastDays: decisionForecastDaySummaries(),
            topDrivers: visibleDriverTexts(from: heroFocusDrivers)
        )
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

    private func extractDriver(keyword: String) -> String? {
        visibleDriverTexts(from: topDrivers).first(where: { $0.localizedCaseInsensitiveContains(keyword) })
    }

    private var heroFocusDrivers: [String] {
        let drivers = heroOpportunitySummary.focusDrivers
        return drivers.isEmpty ? topDrivers : (drivers + topDrivers).uniquePrefix(6)
    }

    private func backendHeroOpportunitySummary(for recommendation: OpportunityRecommendation) -> HeroOpportunitySummary {
        let label = backendDecisionLabel(for: recommendation)
        let tone = backendTone(for: recommendation, label: label)
        let headline = recommendation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? backendFallbackHeadline(for: recommendation, tone: tone)
            : recommendation.title
        let summary = firstUsefulText([
            recommendation.analysis?.summary,
            recommendation.description,
            recommendation.reasons.first
        ]) ?? "Backend boating analysis is available for this window."
        return HeroOpportunitySummary(
            headline: headline,
            subheadline: summary,
            tone: tone,
            badgeText: backendBadgeText(for: recommendation, label: label, tone: tone),
            focusDrivers: backendFocusDrivers(from: recommendation)
        )
    }

    private func backendDecisionLabel(for recommendation: OpportunityRecommendation) -> String {
        firstUsefulText([
            recommendation.analysis?.band,
            recommendation.decisionLabel,
            recommendation.verdict
        ])?.lowercased() ?? ""
    }

    private func backendTone(for recommendation: OpportunityRecommendation, label: String) -> BoatDayRating {
        if label.contains("day_for_it") {
            return .green
        }
        if label.contains("wind_led_watch") || label.contains("worth_watching") || label.contains("watch") {
            return .amber
        }
        if label.contains("not") || label.contains("marginal") || recommendation.finalScore < 55 {
            return .red
        }
        if recommendation.finalScore >= 82 {
            return .green
        }
        return .amber
    }

    private func backendBadgeText(for recommendation: OpportunityRecommendation, label: String, tone: BoatDayRating) -> String {
        if label.contains("day_for_it") || tone == .green {
            return "DAY FOR IT"
        }
        if label.contains("wind_led_watch") {
            return "WIND WATCH"
        }
        if label.contains("watch") || recommendation.verdict.lowercased().contains("watch") || tone == .amber {
            return "WATCH"
        }
        return "HOLD"
    }

    private func backendFallbackHeadline(for recommendation: OpportunityRecommendation, tone: BoatDayRating) -> String {
        let window = opportunityWindowText(for: recommendation.window)
        switch tone {
        case .green:
            return "Day for it: \(window)"
        case .amber:
            if recommendation.analysis?.band == "wind_led_watch" {
                return "Wind watch: \(window)"
            }
            return "Boating watch: \(window)"
        case .red:
            return "Hold off: \(window)"
        }
    }

    private func backendFocusDrivers(from recommendation: OpportunityRecommendation) -> [String] {
        let factorTexts = (recommendation.analysis?.factors ?? []).map { factor in
            let detail = factor.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "\(factor.label): \(Int(factor.score.rounded()))"
            }
            return "\(factor.label): \(detail)"
        }
        return (
            factorTexts +
            recommendation.reasons +
            (recommendation.analysis?.dataSignals ?? []) +
            recommendation.riskFlags
        )
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .uniquePrefix(6)
    }

    private func marineEvidenceStatus(for recommendation: OpportunityRecommendation) -> MarineEvidenceStatus {
        let seaDetail = firstUsefulText([
            explicitSeaSignalText(for: recommendation),
            seaFactorDetail(for: recommendation)
        ])

        if recommendationHasKnownSeaData(recommendation) {
            return MarineEvidenceStatus(
                title: waveSwellEvidenceTitle(for: recommendation),
                detail: seaDetail ?? "Wave height or swell height is part of this score.",
                valueText: heroWavesText,
                isConfirmed: true
            )
        }

        let detail: String
        if recommendation.analysis?.band == "wind_led_watch" {
            detail = "Low wind is only a candidate signal until wave height and swell data confirm it."
        } else {
            detail = seaFactorDetail(for: recommendation) ?? "No explicit wave height or swell signal is available for this window."
        }

        return MarineEvidenceStatus(
            title: "Wave/swell missing",
            detail: detail,
            valueText: "Awaiting waves",
            isConfirmed: false
        )
    }

    private func waveSwellEvidenceTitle(for recommendation: OpportunityRecommendation) -> String {
        let signals = recommendation.analysis?.dataSignals ?? []
        let hasWave = signals.contains { $0.lowercased().hasPrefix("wave ") }
        let hasSwell = signals.contains { $0.lowercased().hasPrefix("swell ") }
        let hasPeriod = signals.contains { $0.lowercased().hasPrefix("period ") }

        if hasWave && hasSwell && hasPeriod {
            return "Wave + swell + period"
        }
        if hasWave && hasSwell {
            return "Wave + swell data"
        }
        if hasWave {
            return "Wave height data"
        }
        if hasSwell {
            return "Swell height data"
        }
        return "Wave/swell model"
    }

    private func recommendationHasKnownSeaData(_ recommendation: OpportunityRecommendation) -> Bool {
        let signals = recommendation.analysis?.dataSignals ?? []
        let hasExplicitSignal = signals.contains { signal in
            let lower = signal.lowercased()
            return lower.hasPrefix("wave ") || lower.hasPrefix("swell ")
        }

        let seaDetail = seaFactorDetail(for: recommendation)?.lowercased() ?? ""
        let hasExplicitFactor = seaDetail.contains("roughness index") && !seaDetail.contains("estimated from wind")

        let sourceStatus = recommendation.analysis?.sourceStatus.map { $0.lowercased() } ?? []
        let waveMissing = sourceStatus.contains { $0.contains("wave_height") && $0.contains("missing") }
        let swellMissing = sourceStatus.contains { $0.contains("swell_height") && $0.contains("missing") }
        let explicitlyEstimated = seaDetail.contains("estimated from wind") || recommendation.analysis?.band == "wind_led_watch"

        return (hasExplicitSignal || hasExplicitFactor) && !(waveMissing && swellMissing) && !explicitlyEstimated
    }

    private func isDisplayableOpportunityRecommendation(_ recommendation: OpportunityRecommendation) -> Bool {
        guard recommendation.activity == "boating" else { return true }
        return isDefaultBoatingDaylightWindow(recommendation.window)
    }

    private func isDefaultBoatingDaylightWindow(_ window: OpportunityRecommendation.Window) -> Bool {
        let calendar = Calendar.current
        guard calendar.isDate(window.start, inSameDayAs: window.end) else {
            return false
        }
        let startMinutes = calendar.component(.hour, from: window.start) * 60 + calendar.component(.minute, from: window.start)
        let endMinutes = calendar.component(.hour, from: window.end) * 60 + calendar.component(.minute, from: window.end)
        return startMinutes >= 5 * 60 && endMinutes <= 18 * 60
    }

    private func explicitSeaSignalText(for recommendation: OpportunityRecommendation) -> String? {
        let seaSignals = (recommendation.analysis?.dataSignals ?? []).filter { signal in
            let lower = signal.lowercased()
            return lower.hasPrefix("wave ") || lower.hasPrefix("swell ") || lower.hasPrefix("period ")
        }
        guard !seaSignals.isEmpty else { return nil }
        return seaSignals.prefix(3).joined(separator: " · ")
    }

    private func seaFactorDetail(for recommendation: OpportunityRecommendation) -> String? {
        let factor = recommendation.analysis?.factors.first { factor in
            let lowerID = factor.id.lowercased()
            let lowerLabel = factor.label.lowercased()
            return lowerID.contains("sea") || lowerID.contains("swell") || lowerID.contains("wave") ||
                lowerLabel.contains("sea") || lowerLabel.contains("swell") || lowerLabel.contains("wave")
        }
        let detail = factor?.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail?.isEmpty == false ? detail : nil
    }

    private func localKnownSeaDetail() -> String? {
        let drivers = visibleDriverTexts(from: heroFocusDrivers)
        return drivers.first { line in
            let lower = line.lowercased()
            let hasSeaWord = lower.contains("sea") || lower.contains("swell") || lower.contains("wave")
            let isWindEstimate = lower.contains("estimated from wind") || lower.contains("wind proxy")
            return hasSeaWord && !isWindEstimate
        }
    }

    private func opportunityWindowText(for window: OpportunityRecommendation.Window) -> String {
        let calendar = Calendar.current
        let dayText: String
        if calendar.isDateInToday(window.start) {
            dayText = "Today"
        } else if calendar.isDateInTomorrow(window.start) {
            dayText = "Tomorrow"
        } else {
            dayText = Self.shortDayFormatter.string(from: window.start)
        }
        return "\(dayText), \(Self.compactTimeText(from: window.start))"
    }

    private func firstUsefulText(_ values: [String?]) -> String? {
        values.compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }.first
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
        switch day.availability {
        case .available:
            parts.append("official forecast available")
        case .unavailable:
            parts.append("limited official data")
        }
        parts.append(seaSignalContextText(for: day))
        parts.append("\(day.confidence.lowercased()) confidence")
        parts.append(day.warningLimited ? "warning cap applied" : "sea state weighted first")
        return parts.joined(separator: " · ")
    }

    private func forecastEvidenceLabel(for day: DailyMarineSummary) -> String {
        let hasSeaSignal = seaSignalContextText(for: day) == "wave/swell signal present"
        switch day.confidence.lowercased() {
        case "high":
            return hasSeaSignal ? "Wave + swell" : "Wind/tide/rain"
        case "medium":
            return hasSeaSignal ? "Wave data" : "Wind + tide"
        default:
            return hasSeaSignal ? "Limited waves" : "Wind only"
        }
    }

    private func seaSignalContextText(for day: DailyMarineSummary) -> String {
        let drivers = visibleDriverTexts(from: day.topDrivers)
        let hasKnownSeaSignal = drivers.contains { line in
            let lower = line.lowercased()
            let hasSeaWord = lower.contains("sea") || lower.contains("swell") || lower.contains("wave")
            let isWindEstimate = lower.contains("estimated from wind") || lower.contains("wind proxy")
            return hasSeaWord && !isWindEstimate
        }
        return hasKnownSeaSignal ? "wave/swell signal present" : "wind is supplementary"
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

    private func tideEventDisplay(prefix: String, event: TideEventViewPoint?) -> String {
        guard let event else { return "\(prefix) --" }
        let time = Self.timeFormatter.string(from: event.time)
        if let height = event.heightMeters {
            return "\(prefix) \(time) · \(String(format: "%.2f m", height))"
        }
        return "\(prefix) \(time)"
    }

    private func tideSummaryForDecision(recommendation: OpportunityRecommendation?) -> String {
        let page = tidePageForDecision(recommendation: recommendation)
        let events = tideEventsInDisplayWindow(for: page).map(tideEventSummary)
        if !events.isEmpty {
            return "\(page.dayLabel) tides: \(events.joined(separator: "; "))"
        }
        return heroTideText
    }

    private func tideEventsForDecision(recommendation: OpportunityRecommendation?) -> [String] {
        tideEventsInDisplayWindow(for: tidePageForDecision(recommendation: recommendation))
            .map(tideEventSummary)
    }

    private func tidePageForDecision(recommendation: OpportunityRecommendation?) -> TideCardViewData {
        let referenceDate = recommendation?.window.start ?? selectedDaySummary?.dayStart ?? Date()
        let pages = tidePageViewData
        return pages.first { page in
            referenceDate >= page.axisStart && referenceDate < page.axisEnd
        } ?? tideCardViewData
    }

    private func decisionForecastDaySummaries() -> [String] {
        fourDayDetailPages.map { page in
            let score = page.scoreValue.map { "\(Int($0.rounded()))" } ?? "unscored"
            return "\(page.dayLabel): \(score), \(page.rating.label), \(page.evidenceText), \(page.summaryText)"
        }
    }

    private func tideEventsInDisplayWindow(for page: TideCardViewData) -> [TideEventViewPoint] {
        page.events
            .filter { $0.time >= page.axisStart && $0.time < page.axisEnd }
            .sorted { $0.time < $1.time }
    }

    private func tideEventSummary(_ event: TideEventViewPoint) -> String {
        let kind = event.kind == .high ? "High" : "Low"
        let time = Self.timeFormatter.string(from: event.time)
        if let height = event.heightMeters {
            return "\(kind) \(time) \(String(format: "%.2f m", height))"
        }
        return "\(kind) \(time)"
    }

    private func buildTideCardViewData(pageOffset: Int) -> TideCardViewData {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let axisStart = calendar.date(byAdding: .day, value: pageOffset, to: todayStart) ?? todayStart
        let axisEnd = calendar.date(byAdding: .day, value: 1, to: axisStart) ?? axisStart
        let eventLookback = calendar.date(byAdding: .hour, value: -6, to: axisStart) ?? axisStart
        let eventLookahead = calendar.date(byAdding: .hour, value: 6, to: axisEnd) ?? axisEnd

        let authoritativeEvents = (tideForecast?.days ?? [])
            .flatMap(\.events)
            .filter { $0.time >= eventLookback && $0.time <= eventLookahead }
            .sorted { $0.time < $1.time }

        let providerSamples = (tideForecast?.days ?? [])
            .flatMap(\.samples)
            .filter { $0.time >= axisStart && $0.time < axisEnd }
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
            note = "Official tide samples · midnight to midnight"
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
            note = "Interpolated from official tide extrema · midnight to midnight"
        } else {
            series = .unavailable
            note = "Official tide data unavailable."
        }

        let nextHigh = chosenEvents.first(where: { $0.kind == .high && $0.time >= axisStart && $0.time < axisEnd }) ?? chosenEvents.first(where: { $0.kind == .high && $0.time >= axisStart })
        let nextLow = chosenEvents.first(where: { $0.kind == .low && $0.time >= axisStart && $0.time < axisEnd }) ?? chosenEvents.first(where: { $0.kind == .low && $0.time >= axisStart })
        let chartMaximumMeters = tideChartMaximumMeters(series: series, events: chosenEvents)
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
            chartMaximumMeters: chartMaximumMeters,
            note: tideStatusMessage ?? note
        )
    }

    private func tideChartMaximumMeters(series: TideSeriesSource, events: [TideEventViewPoint]) -> Double {
        let sampleHeights: [Double]
        switch series {
        case let .sampled(points), let .eventInterpolated(points):
            sampleHeights = points.map(\.heightMeters)
        case .unavailable:
            sampleHeights = []
        }
        let visibleMaximum = (sampleHeights + events.compactMap(\.heightMeters))
            .filter { $0.isFinite && $0 > 0 }
            .max() ?? 0
        let stationMaximum = tideForecast?.chartMaximumMeters ?? Self.defaultTideChartMaximumMeters
        return max(1.0, stationMaximum, visibleMaximum)
    }

    private func tidePageLabel(for date: Date, offset: Int) -> String {
        Self.shortDayFormatter.string(from: date)
    }

    private func tideWindowLabel(from start: Date, to end: Date, offset: Int) -> String {
        "Midnight to midnight"
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
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    private static func compactTimeText(from date: Date) -> String {
        let minute = Calendar.current.component(.minute, from: date)
        return (minute == 0 ? hourOnlyTimeFormatter : timeFormatter).string(from: date)
    }

    private static let hourOnlyTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
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

    private static let localForecastRequestDays = 10
    private static let localForecastDisplayDays = 7
    private static let defaultTideChartMaximumMeters = 4.0

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
                observationProductID: "IDN60801",
                observationStationWMO: 95766,
                marineWarningRSSPath: "/fwo/IDZ00068.warnings_marine_nsw.xml",
                preferredCoastalAAC: "NSW_MW004"
            )
        case .melbourne:
            return MarineFeedConfig(
                coastalProductID: "IDV10200",
                observationProductID: "IDV60801",
                observationStationWMO: 94892,
                marineWarningRSSPath: "/fwo/IDZ00073.warnings_marine_vic.xml",
                preferredCoastalAAC: "VIC_MW002"
            )
        case .brisbane:
            return MarineFeedConfig(
                coastalProductID: "IDQ11290",
                observationProductID: "IDQ60801",
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

private struct QLDObservationStation {
    let productID: String
    let wmo: Int
    let latitude: Double
    let longitude: Double

    static let all: [QLDObservationStation] = [
        .init(productID: "IDQ60801", wmo: 94280, latitude: -17.56, longitude: 146.01), // Innisfail Aerodrome
        .init(productID: "IDQ60801", wmo: 94287, latitude: -16.87, longitude: 145.75), // Cairns Aero
        .init(productID: "IDQ60801", wmo: 94285, latitude: -16.38, longitude: 145.56), // Low Isles Lighthouse
        .init(productID: "IDQ60801", wmo: 94294, latitude: -19.25, longitude: 146.77), // Townsville Aero
        .init(productID: "IDQ60801", wmo: 94368, latitude: -20.37, longitude: 148.95), // Hamilton Island Airport
        .init(productID: "IDQ60801", wmo: 94367, latitude: -21.12, longitude: 149.22), // Mackay M.O
        .init(productID: "IDQ60801", wmo: 94373, latitude: -23.14, longitude: 150.75), // Yeppoon
        .init(productID: "IDQ60801", wmo: 94380, latitude: -23.86, longitude: 151.26), // Gladstone
        .init(productID: "IDQ60801", wmo: 94387, latitude: -24.91, longitude: 152.32), // Bundaberg Aero
        .init(productID: "IDQ60801", wmo: 95565, latitude: -25.32, longitude: 152.88), // Hervey Bay Airport
        .init(productID: "IDQ60801", wmo: 94569, latitude: -26.60, longitude: 153.09), // Sunshine Coast Airport
        .init(productID: "IDQ60801", wmo: 94576, latitude: -27.48, longitude: 153.04), // Brisbane
        .init(productID: "IDQ60801", wmo: 94580, latitude: -27.94, longitude: 153.43), // Gold Coast Seaway
    ]

    static func nearest(to coord: CLLocationCoordinate2D) -> QLDObservationStation? {
        all.min(by: { lhs, rhs in
            let d1 = hypot(lhs.latitude - coord.latitude, lhs.longitude - coord.longitude)
            let d2 = hypot(rhs.latitude - coord.latitude, rhs.longitude - coord.longitude)
            return d1 < d2
        })
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
