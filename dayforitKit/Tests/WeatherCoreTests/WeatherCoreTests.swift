import XCTest
@testable import WeatherCore

final class WeatherCoreTests: XCTestCase {
    func testMarineTextMaxWindParsesKnotsRange() {
        let text = "Southerly 10 to 15 knots, reaching up to 20 knots inshore."
        let speed = MarineTextMetrics.maxWindKmh(from: text)
        XCTAssertNotNil(speed)
        XCTAssertGreaterThan(speed ?? 0, 35)
    }

    func testMarineWarningsSeverityMapping() {
        XCTAssertEqual(MarineWarningsParser.mapSeverity(title: "Gale Warning"), .gale)
        XCTAssertEqual(MarineWarningsParser.mapSeverity(title: "Strong Wind Warning"), .strong)
    }

    func testMarineWarningsParserIgnoresSummaryOnlyItems() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8" ?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>27/09:00 EST Marine Wind Warning Summary for Queensland</title>
                    <link>http://example.com/summary</link>
                </item>
            </channel>
        </rss>
        """

        let warnings = try MarineWarningsParser.parse(data: Data(xml.utf8))
        XCTAssertTrue(warnings.isEmpty)
    }

    func testTidePredictionProviderPreservesExtremaEvents() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Brisbane")!
        let dayStart = Date(timeIntervalSince1970: 1_776_694_400)
        let high = TideEventPoint(
            time: Date(timeInterval: 6 * 60 * 60, since: dayStart),
            kind: .high,
            heightMeters: 2.1,
            source: .authoritative
        )
        let low = TideEventPoint(
            time: Date(timeInterval: 12 * 60 * 60, since: dayStart),
            kind: .low,
            heightMeters: 0.4,
            source: .authoritative
        )
        let forecast = TideForecast(
            generatedAt: dayStart,
            provider: "test-provider",
            locationName: "Test Coast",
            stationName: "Test Station",
            days: [
                TideDayForecast(dayStart: dayStart, events: [high, low], samples: []),
            ]
        )
        let provider = TideForecastPredictionProvider(provider: StubTideDataProvider(forecast: forecast), calendar: calendar)
        let location = BoatingLocation(
            name: "Test Coast",
            latitude: -26.8,
            longitude: 153.1,
            timeZoneID: "Australia/Brisbane",
            bindings: ProviderBindings(tideStationID: "test-station")
        )

        let predictions = try await provider.fetchTides(location: location, days: 1)

        XCTAssertEqual(predictions.first?.events.count, 2)
        XCTAssertEqual(predictions.first?.events.first?.kind, .high)
        XCTAssertEqual(predictions.first?.events.first?.heightM.value, 2.1)
        XCTAssertTrue(predictions.first?.summary?.contains("1 high, 1 low") == true)
    }

    func testQueenslandWaveParserSelectsLatestNearestBuoy() throws {
        let csv = """
        Wave Data provided @ 10:01hrs on 28-04-2026
        Site, SiteNumber, Seconds, DateTime, Latitude, Longitude, Hsig, Hmax, Tp, Tz, SST, Direction, Current Speed, Current Direction
        Caloundra,54,1776693600,2026-04-21T00:00:00,-26.84679,153.15538,0.992,1.670,14.290,5.063,25.10,102.70,-99.90,-99.90
        Caloundra,54,1776700800,2026-04-21T02:00:00,-26.84624,153.15583,1.200,1.900,15.380,5.128,25.30,98.40,-99.90,-99.90
        Gold Coast,52,1776700800,2026-04-21T02:00:00,-27.94710,153.44910,0.700,1.200,8.100,4.900,24.80,115.00,-99.90,-99.90
        """
        let records = try QueenslandWaveDataProvider.parseWaveCSV(Data(csv.utf8))
        let location = BoatingLocation(
            name: "Mooloolaba",
            latitude: -26.68,
            longitude: 153.13,
            timeZoneID: "Australia/Brisbane"
        )

        let best = QueenslandWaveDataProvider.bestRecord(for: location, from: records)

        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(best?.site, "Caloundra")
        XCTAssertEqual(best?.significantHeightM, 1.2)
        XCTAssertEqual(best?.seaSurfaceTempC, 25.3)
    }

    func testQueenslandTideProviderRejectsOutsideQueensland() async {
        let provider = QueenslandTideDataProvider()
        let locations = [
            MarineLocation(
                name: "Sydney Harbour",
                latitude: -33.843,
                longitude: 151.255,
                timeZoneID: "Australia/Sydney"
            ),
            MarineLocation(
                name: "Byron Bay",
                latitude: -28.647,
                longitude: 153.602,
                timeZoneID: "Australia/Sydney"
            ),
        ]

        for location in locations {
            do {
                _ = try await provider.fetchTideForecast(
                    location: location,
                    start: Date(),
                    days: 1,
                    sampleIntervalMinutes: nil
                )
                XCTFail("Expected Queensland tide provider to reject \(location.name).")
            } catch QueenslandTideProviderError.noStationAvailable {
                // Expected: national forecast-only areas must not inherit Queensland tide stations.
            } catch {
                XCTFail("Unexpected error for \(location.name): \(error)")
            }
        }
    }

    func testCurrentWarningWithoutWindowOnlyAffectsToday() {
        let now = Date()
        let warning = MarineWarning(
            locationID: UUID(),
            headline: "Strong Wind Warning for Test Coast",
            severity: .strong,
            validWindow: nil,
            issuedAtUTC: now,
            provenance: ProvenanceRef(
                provider: "bom",
                product: "warning",
                sourceObjectID: "QLD_MW007",
                fetchedAtUTC: now,
                parsedAtUTC: now
            )
        )
        let snapshot = MarineSnapshot(
            locationID: UUID(),
            asOfUTC: now,
            forecast: [],
            observations: [],
            tides: [],
            waveForecasts: [],
            waveObservations: [],
            warnings: [warning]
        )

        let inputs = MarineSnapshotAssembler(calendar: .current).buildAssessmentInputs(snapshot: snapshot, forecastDays: 2)

        XCTAssertEqual(inputs.first?.warningSeverity.value, .strong)
        XCTAssertNil(inputs.dropFirst().first?.warningSeverity.value)
    }

    func testAssemblerUsesFreshObservedWindAndWaveSignalsForToday() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let locationID = UUID()
        let forecastProvenance = ProvenanceRef(
            provider: "bom",
            product: "IDQ11290",
            sourceObjectID: "QLD_MW007",
            fetchedAtUTC: now,
            parsedAtUTC: now
        )
        let forecast = MarineForecast(
            locationID: locationID,
            validFor: ValidityWindow(startUTC: start, endUTC: end),
            windSpeedKmh: FieldValue(value: 38, state: .available),
            windGustKmh: FieldValue(value: nil, state: .notProvided),
            waveHeightM: FieldValue(value: nil, state: .missing),
            swellHeightM: FieldValue(value: nil, state: .missing),
            rainfallProb: FieldValue(value: 0.1, state: .available),
            provenance: forecastProvenance
        )
        let observation = MarineObservation(
            locationID: locationID,
            observedAtUTC: now,
            windSpeedKmh: FieldValue(value: 12, state: .available),
            windGustKmh: FieldValue(value: 20, state: .available),
            waveHeightM: FieldValue(value: nil, state: .notProvided),
            seaTempC: FieldValue(value: nil, state: .notProvided),
            provenance: ProvenanceRef(
                provider: "bom",
                product: "IDQ60901",
                sourceObjectID: "94589",
                fetchedAtUTC: now,
                parsedAtUTC: now
            )
        )
        let waveObservation = WaveObservation(
            locationID: locationID,
            observedAtUTC: now,
            significantHeightM: FieldValue(value: 0.8, state: .available, reason: "Observed at Test wave buoy"),
            maximumHeightM: FieldValue(value: 1.4, state: .available),
            peakPeriodS: FieldValue(value: 9, state: .available),
            zeroCrossingPeriodS: FieldValue(value: 5, state: .available),
            directionDeg: FieldValue(value: 105, state: .available),
            seaSurfaceTempC: FieldValue(value: 25.2, state: .available),
            provenance: ProvenanceRef(
                provider: "qld-open-data",
                product: "coastal-data-system-near-real-time-wave-data",
                sourceObjectID: "Test",
                fetchedAtUTC: now,
                parsedAtUTC: now
            )
        )
        let snapshot = MarineSnapshot(
            locationID: locationID,
            asOfUTC: now,
            forecast: [forecast],
            observations: [observation],
            tides: [],
            waveForecasts: [],
            waveObservations: [waveObservation],
            warnings: []
        )
        let assembler = MarineSnapshotAssembler(calendar: calendar)

        let input = assembler.buildAssessmentInputs(snapshot: snapshot, forecastDays: 1).first
        let output = assembler.toLegacyOutput(
            requestLocation: MarineLocation(name: "Test Coast", latitude: -26.8, longitude: 153.1, timeZoneID: "Australia/Brisbane"),
            snapshot: snapshot,
            assessmentInputs: input.map { [$0] } ?? [],
            forecastDays: 1
        )

        XCTAssertEqual(input?.observedWindKmh.value, 12)
        XCTAssertEqual(input?.waveHeightM.value, 0.8)
        XCTAssertTrue(output.daily.first?.topDrivers.contains("Observed waves 0.8 m") == true)
    }

    func testScoringUsesMoreConservativeForecastWhenObservedConditionsAreLower() {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let locationID = UUID()
        let provenance = ProvenanceRef(
            provider: "bom",
            product: "IDQ11290",
            sourceObjectID: "QLD_MW007",
            fetchedAtUTC: now,
            parsedAtUTC: now
        )
        let forecast = MarineForecast(
            locationID: locationID,
            validFor: ValidityWindow(startUTC: start, endUTC: end),
            windSpeedKmh: FieldValue(value: 56, state: .available),
            windGustKmh: FieldValue(value: nil, state: .notProvided),
            waveHeightM: FieldValue(value: 2.0, state: .available, reason: "BOM seas and swell forecast"),
            swellHeightM: FieldValue(value: 1.5, state: .available),
            rainfallProb: FieldValue(value: 0.55, state: .available),
            provenance: provenance
        )
        let observation = MarineObservation(
            locationID: locationID,
            observedAtUTC: now,
            windSpeedKmh: FieldValue(value: 7, state: .available),
            windGustKmh: FieldValue(value: 13, state: .available),
            waveHeightM: FieldValue(value: nil, state: .notProvided),
            seaTempC: FieldValue(value: nil, state: .notProvided),
            provenance: provenance
        )
        let waveObservation = WaveObservation(
            locationID: locationID,
            observedAtUTC: now,
            significantHeightM: FieldValue(value: 0.6, state: .available, reason: "Observed at Test wave buoy"),
            peakPeriodS: FieldValue(value: 4, state: .available),
            directionDeg: FieldValue(value: 100, state: .available),
            provenance: provenance
        )
        let snapshot = MarineSnapshot(
            locationID: locationID,
            asOfUTC: now,
            forecast: [forecast],
            observations: [observation],
            tides: [],
            waveForecasts: [],
            waveObservations: [waveObservation],
            warnings: []
        )
        let assembler = MarineSnapshotAssembler()
        let input = assembler.buildAssessmentInputs(snapshot: snapshot, forecastDays: 1).first!

        let output = assembler.toLegacyOutput(
            requestLocation: MarineLocation(name: "Test Coast", latitude: -17.7, longitude: 146.1, timeZoneID: "Australia/Brisbane"),
            snapshot: snapshot,
            assessmentInputs: [input],
            forecastDays: 1
        )

        XCTAssertEqual(input.waveHeightM.value, 2.0)
        XCTAssertEqual(output.daily.first?.rating, .red)
        XCTAssertTrue(output.daily.first?.topDrivers.contains("Forecast wind up to 56 km/h") == true)
        XCTAssertTrue(output.daily.first?.topDrivers.contains("Forecast seas 2.0 m") == true)
    }

    func testForecastPeriodWithSparseParsedSignalsStillProducesDailyRecommendation() {
        let locationID = UUID()
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let end = Date(timeInterval: 86_400, since: start)
        let provenance = ProvenanceRef(
            provider: "bom",
            product: "IDQ11290",
            sourceObjectID: "QLD_MW007",
            fetchedAtUTC: start,
            parsedAtUTC: start
        )
        let forecast = MarineForecast(
            locationID: locationID,
            validFor: ValidityWindow(startUTC: start, endUTC: end),
            windSpeedKmh: FieldValue(value: nil, state: .missing),
            windGustKmh: FieldValue(value: nil, state: .notProvided),
            waveHeightM: FieldValue(value: nil, state: .missing),
            swellHeightM: FieldValue(value: nil, state: .notProvided),
            rainfallProb: FieldValue(value: nil, state: .unknown),
            provenance: provenance
        )
        let snapshot = MarineSnapshot(
            locationID: locationID,
            asOfUTC: start,
            forecast: [forecast],
            observations: [],
            tides: [],
            waveForecasts: [],
            waveObservations: [],
            warnings: []
        )
        let input = AssessmentInput(
            locationID: locationID,
            targetWindow: ValidityWindow(startUTC: start, endUTC: end),
            forecastWindKmh: forecast.windSpeedKmh,
            tideSuitability: FieldValue(value: nil, state: .notProvided),
            rainProbability: forecast.rainfallProb,
            warningSeverity: FieldValue(value: nil, state: .notProvided),
            provenanceRefs: [provenance]
        )

        let output = MarineSnapshotAssembler().toLegacyOutput(
            requestLocation: MarineLocation(name: "Test Coast", latitude: -17.6, longitude: 146.1),
            snapshot: snapshot,
            assessmentInputs: [input],
            forecastDays: 1
        )

        XCTAssertEqual(output.daily.first?.availability, .available)
        XCTAssertNotNil(output.daily.first?.pleasantness)
        XCTAssertFalse(output.daily.first?.topDrivers.contains { $0.localizedCaseInsensitiveContains("pending") } == true)
    }

    func testParsersReadFixtureContent() throws {
        let bundle = Bundle.module
        let coastalURL = bundle.url(forResource: "coastal_sample", withExtension: "xml", subdirectory: "Fixtures")!
        let warningsURL = bundle.url(forResource: "warnings_sample", withExtension: "xml", subdirectory: "Fixtures")!
        let coastalData = try Data(contentsOf: coastalURL)
        let warningData = try Data(contentsOf: warningsURL)

        let coastalDoc = try CoastalWaterXMLParser.parse(data: coastalData)
        let warnings = try MarineWarningsParser.parse(data: warningData)

        XCTAssertEqual(coastalDoc.productId, "IDN11001")
        XCTAssertEqual(warnings.count, 2)
        XCTAssertTrue(coastalDoc.areas.first?.periods.first?.forecastWinds?.contains("10 to 15 knots") == true)
    }
}

private struct StubTideDataProvider: TideDataProvider, Sendable {
    let forecast: TideForecast

    func fetchTideForecast(
        location: MarineLocation,
        start: Date,
        days: Int,
        sampleIntervalMinutes: Int?
    ) async throws -> TideForecast {
        forecast
    }
}
