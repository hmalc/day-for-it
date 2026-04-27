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
        XCTAssertTrue(output.daily.first?.topDrivers.contains("Wind detail pending") == true)
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
