import XCTest
@testable import PleasantnessEngine

final class DayVerdictScorerTests: XCTestCase {
    func testGlassyDayWithLightWindIsADayForIt() {
        let out = DayVerdictScorer.verdict(windKmh: 10, seasM: 0.3)

        XCTAssertEqual(out?.verdict, .dayForIt)
        XCTAssertTrue(out?.reasons.contains("Glassy seas (0.3 m)") == true)
    }

    func testWorstFactorWinsRoughSeasOverrideLightWind() {
        let out = DayVerdictScorer.verdict(windKmh: 10, seasM: 2.0)

        XCTAssertEqual(out?.verdict, .poor)
        XCTAssertEqual(out?.limitedBy, "Rough seas (2.0 m)")
    }

    func testModerateWindCapsAGlassyDayAtIfYouMust() {
        let out = DayVerdictScorer.verdict(windKmh: 28, seasM: 0.4)

        XCTAssertEqual(out?.verdict, .ifYouMust)
        XCTAssertEqual(out?.limitedBy, "Moderate winds (~28 km/h)")
    }

    func testSevereWarningMeansNotAChance() {
        let out = DayVerdictScorer.verdict(windKmh: 12, seasM: 0.4, warning: .severe)

        XCTAssertEqual(out?.verdict, .notAChance)
        XCTAssertEqual(out?.limitedBy, "Gale or storm-tier marine warning active")
    }

    func testStrongWindWarningCapsAtPoor() {
        let out = DayVerdictScorer.verdict(windKmh: 12, seasM: 0.4, warning: .strong)

        XCTAssertEqual(out?.verdict, .poor)
    }

    func testMissingSeaStateCapsCeilingAtDecent() {
        let out = DayVerdictScorer.verdict(windKmh: 6, seasM: nil)

        XCTAssertEqual(out?.verdict, .decent)
        XCTAssertEqual(out?.limitedBy, "Sea state not quantified")
    }

    func testMissingWindCapsCeilingAtDecent() {
        let out = DayVerdictScorer.verdict(windKmh: nil, seasM: 0.2)

        XCTAssertEqual(out?.verdict, .decent)
        XCTAssertEqual(out?.limitedBy, "Wind not quantified")
    }

    func testNoWindAndNoSeaDataMeansNoVerdict() {
        XCTAssertNil(DayVerdictScorer.verdict(windKmh: nil, seasM: nil))
    }

    func testGustsRaiseEffectiveWind() {
        // 12 km/h sustained but 60 km/h gusts: effective 45 km/h -> poor.
        let out = DayVerdictScorer.verdict(windKmh: 12, windGustKmh: 60, seasM: 0.4)

        XCTAssertEqual(out?.verdict, .poor)
    }

    func testThunderstormMentionCapsAtIfYouMust() {
        let out = DayVerdictScorer.verdict(windKmh: 8, seasM: 0.3, severeWeatherMention: "thunderstorms")

        XCTAssertEqual(out?.verdict, .ifYouMust)
        XCTAssertEqual(out?.limitedBy, "Forecast mentions thunderstorms")
    }

    func testVeryStrongWindIsNotAChance() {
        let out = DayVerdictScorer.verdict(windKmh: 55, seasM: 0.8)

        XCTAssertEqual(out?.verdict, .notAChance)
    }

    func testReasonsListWorstFactorFirst() {
        let out = DayVerdictScorer.verdict(windKmh: 40, seasM: 0.3)

        XCTAssertEqual(out?.reasons.first, "Fresh winds (~40 km/h)")
    }

    func testVerdictOrderingMatchesLadder() {
        XCTAssertLessThan(DayVerdict.notAChance, .poor)
        XCTAssertLessThan(DayVerdict.poor, .ifYouMust)
        XCTAssertLessThan(DayVerdict.ifYouMust, .decent)
        XCTAssertLessThan(DayVerdict.decent, .dayForIt)
    }
}
