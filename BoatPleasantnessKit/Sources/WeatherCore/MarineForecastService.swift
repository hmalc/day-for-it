import Foundation

public struct MarineForecastService: Sendable {
    private let providers: ProviderFacade
    private let assembler: MarineSnapshotAssembler

    public init(
        bomClient: BOMHTTPClient = .init(),
        tideProvider: TideDataProvider = QueenslandTideDataProvider(),
        calendar: Calendar = .current
    ) {
        providers = ProviderFacade(
            forecastProvider: BOMMarineForecastProvider(client: bomClient, calendar: calendar),
            observationProvider: BOMObservationProvider(client: bomClient),
            warningProvider: BOMWarningProvider(client: bomClient),
            tideProvider: TideForecastPredictionProvider(provider: tideProvider, calendar: calendar)
        )
        assembler = MarineSnapshotAssembler(calendar: calendar)
    }

    public func fetchSevenDayForecast(request: MarineForecastRequest) async throws -> MarineForecastOutput {
        let boatingLocation = request.location.toBoatingLocation(feed: request.feed)

        async let forecastResult: [MarineForecast]? = try? await providers.forecastProvider.fetchForecast(
            location: boatingLocation,
            feed: request.feed,
            days: request.forecastDays
        )
        async let observationResult: MarineObservation? = try? await providers.observationProvider.fetchLatestObservation(
            location: boatingLocation,
            feed: request.feed
        )
        async let warningsResult: [MarineWarning]? = try? await providers.warningProvider.fetchWarnings(
            location: boatingLocation,
            feed: request.feed
        )
        async let tidesResult: [TidePrediction]? = try? await providers.tideProvider.fetchTides(
            location: boatingLocation,
            days: request.forecastDays
        )

        let forecast = await forecastResult ?? []
        let observation = await observationResult
        let warnings = await warningsResult ?? []
        let tides = await tidesResult ?? []

        if forecast.isEmpty, observation == nil, warnings.isEmpty {
            let now = Date()
            let daily = Self.placeholderDays(
                from: now,
                forecastDays: request.forecastDays,
                includeToday: false,
                calendar: .current,
                reason: "Network issue while reaching forecast services."
            )
            return MarineForecastOutput(
                location: request.location,
                generatedAt: now,
                hourly: [],
                daily: daily,
                warnings: [],
                coastalExcerpt: nil,
                dataQuality: .minimal,
                degradedReason: "Network issue while reaching forecast services. Please retry."
            )
        }

        let snapshot = assembler.assembleSnapshot(
            location: boatingLocation,
            forecast: forecast,
            observations: observation.map { [$0] } ?? [],
            tides: tides,
            warnings: warnings
        )
        let assessmentInputs = assembler.buildAssessmentInputs(snapshot: snapshot, forecastDays: request.forecastDays)
        return assembler.toLegacyOutput(
            requestLocation: request.location,
            snapshot: snapshot,
            assessmentInputs: assessmentInputs,
            forecastDays: request.forecastDays
        )
    }

    private static func placeholderDays(
        from start: Date,
        forecastDays: Int,
        includeToday: Bool,
        calendar: Calendar,
        reason: String
    ) -> [DailyMarineSummary] {
        let day0 = calendar.startOfDay(for: start)
        return (0 ..< max(1, forecastDays)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: day0) else { return nil }
            let isToday = offset == 0
            return DailyMarineSummary(
                dayStart: day,
                pleasantness: includeToday && isToday ? 50 : nil,
                rating: includeToday && isToday ? .amber : .red,
                availability: includeToday && isToday ? .available : .unavailable,
                confidence: "low",
                warningLimited: false,
                topDrivers: [reason]
            )
        }
    }

}
