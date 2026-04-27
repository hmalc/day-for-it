import Foundation

public protocol MarineForecastProvider: Sendable {
    func fetchForecast(location: BoatingLocation, feed: MarineFeedConfig, days: Int) async throws -> [MarineForecast]
}

public protocol MarineObservationProvider: Sendable {
    func fetchLatestObservation(location: BoatingLocation, feed: MarineFeedConfig) async throws -> MarineObservation?
}

public protocol MarineWarningProvider: Sendable {
    func fetchWarnings(location: BoatingLocation, feed: MarineFeedConfig) async throws -> [MarineWarning]
}

public protocol TidePredictionProvider: Sendable {
    func fetchTides(location: BoatingLocation, days: Int) async throws -> [TidePrediction]
}

public protocol WaveProvider: Sendable {
    func fetchWaveForecast(location: BoatingLocation, days: Int) async throws -> [WaveForecast]
    func fetchWaveObservation(location: BoatingLocation) async throws -> [WaveObservation]
}

public struct ProviderFacade: Sendable {
    public var forecastProvider: MarineForecastProvider
    public var observationProvider: MarineObservationProvider
    public var warningProvider: MarineWarningProvider
    public var tideProvider: TidePredictionProvider

    public init(
        forecastProvider: MarineForecastProvider,
        observationProvider: MarineObservationProvider,
        warningProvider: MarineWarningProvider,
        tideProvider: TidePredictionProvider
    ) {
        self.forecastProvider = forecastProvider
        self.observationProvider = observationProvider
        self.warningProvider = warningProvider
        self.tideProvider = tideProvider
    }
}

public struct BOMMarineForecastProvider: MarineForecastProvider, Sendable {
    private let client: BOMHTTPClient
    private let calendar: Calendar

    public init(client: BOMHTTPClient = .init(), calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    public func fetchForecast(location: BoatingLocation, feed: MarineFeedConfig, days: Int) async throws -> [MarineForecast] {
        let fetchedAt = Date()
        let data = try await client.data(from: BOMConfig.coastalForecastURL(productId: feed.coastalProductID))
        let doc = try CoastalWaterXMLParser.parse(data: data)
        let coasts = doc.areas.filter { $0.areaType == "coast" }
        let chosen = coasts.first(where: { $0.aac == location.bindings.bomCoastalAAC }) ?? coasts.first ?? doc.areas.first
        guard let area = chosen else { return [] }
        let parsedAt = Date()

        let periods = area.periods.prefix(max(1, days))
        return periods.map { period in
            let start = period.startUTC ?? fetchedAt
            let end = period.endUTC ?? calendar.date(byAdding: .hour, value: 24, to: start) ?? start
            let windsText = [period.forecastWinds].compactMap { $0 }.joined(separator: " ")
            let seasText = [period.forecastSeas, period.forecastSwell1, period.forecastSwell2].compactMap { $0 }.joined(separator: " ")
            let weatherText = [period.forecastWeather, period.forecastCaution].compactMap { $0 }.joined(separator: " ")

            let wind = MarineTextMetrics.maxWindKmh(from: windsText)
            let seas = MarineTextMetrics.maxMetres(from: seasText)
            let rain = MarineSnapshotAssembler.heuristicRainProbability(from: weatherText)

            return MarineForecast(
                locationID: location.id,
                validFor: ValidityWindow(startUTC: start, endUTC: end),
                windSpeedKmh: FieldValue(value: wind, state: wind == nil ? .missing : .available),
                windGustKmh: FieldValue(value: nil, state: .notProvided),
                waveHeightM: FieldValue(value: seas, state: seas == nil ? .missing : .available),
                swellHeightM: FieldValue(value: nil, state: .notProvided),
                rainfallProb: FieldValue(value: rain, state: rain == nil ? .unknown : .available),
                freshness: .fresh,
                provenance: ProvenanceRef(
                    provider: "bom",
                    product: feed.coastalProductID,
                    sourceObjectID: area.aac,
                    fetchedAtUTC: fetchedAt,
                    parsedAtUTC: parsedAt,
                    issuedAtUTC: doc.issueTimeUTC
                )
            )
        }
    }
}

public struct BOMObservationProvider: MarineObservationProvider, Sendable {
    private let client: BOMHTTPClient

    public init(client: BOMHTTPClient = .init()) {
        self.client = client
    }

    public func fetchLatestObservation(location: BoatingLocation, feed: MarineFeedConfig) async throws -> MarineObservation? {
        let fetchedAt = Date()
        let data = try await client.data(
            from: BOMConfig.observationURL(productId: feed.observationProductID, stationWmo: feed.observationStationWMO)
        )
        let decoded = try JSONDecoder().decode(FWOObservationResponse.self, from: data)
        guard let datum = decoded.observations.data?.first else { return nil }
        let parsedAt = Date()
        let observedAt = Self.parseObservationTime(datum.local_date_time_full) ?? parsedAt

        let wind = datum.wind_spd_kmh.map(Double.init)
        let gust = datum.gust_kmh.map(Double.init)
        let temp = datum.air_temp

        return MarineObservation(
            locationID: location.id,
            observedAtUTC: observedAt,
            windSpeedKmh: FieldValue(value: wind, state: wind == nil ? .missing : .available),
            windGustKmh: FieldValue(value: gust, state: gust == nil ? .missing : .available),
            waveHeightM: FieldValue(value: nil, state: .notProvided),
            seaTempC: FieldValue(value: temp, state: temp == nil ? .missing : .available),
            freshness: .fresh,
            provenance: ProvenanceRef(
                provider: "bom",
                product: feed.observationProductID,
                sourceObjectID: String(feed.observationStationWMO),
                fetchedAtUTC: fetchedAt,
                parsedAtUTC: parsedAt
            )
        )
    }

    private static func parseObservationTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.date(from: raw)
    }
}

public struct BOMWarningProvider: MarineWarningProvider, Sendable {
    private let client: BOMHTTPClient

    public init(client: BOMHTTPClient = .init()) {
        self.client = client
    }

    public func fetchWarnings(location: BoatingLocation, feed: MarineFeedConfig) async throws -> [MarineWarning] {
        let path = location.bindings.bomMarineWarningPath ?? feed.marineWarningRSSPath
        let url = URL(string: "https://www.bom.gov.au\(path)")!
        let fetchedAt = Date()
        let data = try await client.data(from: url)
        let parsed = try MarineWarningsParser.parse(data: data)
        let parsedAt = Date()

        return parsed.map { item in
            MarineWarning(
                locationID: location.id,
                headline: item.title,
                severity: Self.mapSeverity(item.title),
                validWindow: nil,
                issuedAtUTC: nil,
                freshness: .unknown,
                provenance: ProvenanceRef(
                    provider: "bom",
                    product: path,
                    sourceObjectID: location.bindings.bomCoastalAAC,
                    fetchedAtUTC: fetchedAt,
                    parsedAtUTC: parsedAt
                )
            )
        }
    }

    private static func mapSeverity(_ title: String) -> MarineWarningSeverity {
        switch MarineWarningsParser.mapSeverity(title: title) {
        case .storm, .gale: return .severe
        case .strong: return .strong
        case .advisory: return .minor
        }
    }
}

public struct TideForecastPredictionProvider: TidePredictionProvider, Sendable {
    private let provider: TideDataProvider
    private let calendar: Calendar

    public init(provider: TideDataProvider, calendar: Calendar = .current) {
        self.provider = provider
        self.calendar = calendar
    }

    public func fetchTides(location: BoatingLocation, days: Int) async throws -> [TidePrediction] {
        let forecast = try await provider.fetchTideForecast(
            location: MarineLocation(
                name: location.name,
                latitude: location.latitude,
                longitude: location.longitude,
                timeZoneID: location.timeZoneID
            ),
            start: Date(),
            days: days,
            sampleIntervalMinutes: 20
        )

        let now = Date()
        return forecast.days.map { day in
            let hasHigh = day.events.contains { $0.kind == .high }
            let hasLow = day.events.contains { $0.kind == .low }
            let suitability = (hasHigh && hasLow) ? 0.75 : (!day.events.isEmpty ? 0.5 : 0.25)
            let summary = hasHigh && hasLow ? "Two-way tide movement" : "Limited tide movement"
            let end = calendar.date(byAdding: .day, value: 1, to: day.dayStart) ?? day.dayStart
            return TidePrediction(
                locationID: location.id,
                window: ValidityWindow(startUTC: day.dayStart, endUTC: end),
                events: [],
                suitability: FieldValue(value: suitability, state: .available),
                summary: summary,
                freshness: .fresh,
                provenance: ProvenanceRef(
                    provider: forecast.provider,
                    product: "normalized-forecast",
                    sourceObjectID: location.bindings.tideStationID,
                    fetchedAtUTC: now,
                    parsedAtUTC: now
                )
            )
        }
    }
}
