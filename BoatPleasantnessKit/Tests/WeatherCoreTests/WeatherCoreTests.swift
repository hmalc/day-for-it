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

    func testParsersReadFixtureContent() throws {
        let bundle = Bundle.module
        let coastalURL = bundle.url(forResource: "coastal_sample", withExtension: "xml")!
        let warningsURL = bundle.url(forResource: "warnings_sample", withExtension: "xml")!
        let coastalData = try Data(contentsOf: coastalURL)
        let warningData = try Data(contentsOf: warningsURL)

        let coastalDoc = try CoastalWaterXMLParser.parse(data: coastalData)
        let warnings = try MarineWarningsParser.parse(data: warningData)

        XCTAssertEqual(coastalDoc.productId, "IDN11001")
        XCTAssertEqual(warnings.count, 2)
        XCTAssertTrue(coastalDoc.areas.first?.periods.first?.forecastWinds?.contains("10 to 15 knots") == true)
    }
}
