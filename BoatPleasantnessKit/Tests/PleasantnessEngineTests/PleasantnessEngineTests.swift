import XCTest
@testable import PleasantnessEngine

final class PleasantnessEngineTests: XCTestCase {
    func testWarningCapApplies() {
        let input = ScoringInput(
            windSpeedKmh: 12,
            seaHeightMetres: 0.8,
            activeWarnings: [
                .init(title: "Gale Warning", severity: .gale),
            ]
        )
        let result = PleasantnessEngine.evaluate(input)
        XCTAssertLessThanOrEqual(result.index, 28)
        XCTAssertTrue(result.isWarningLimited)
    }

    func testBoatDayScorerWindAndTideDriveGreen() {
        let out = BoatDayScorer.score(
            windKmh: 14,
            tideSuitability: 0.8,
            rainProbability: 0.1,
            hasStrongWarning: false
        )
        XCTAssertEqual(out.rating, .green)
        XCTAssertGreaterThan(out.score, 65)
    }

    func testBoatDayScorerStrongWarningCapsRed() {
        let out = BoatDayScorer.score(
            windKmh: 18,
            tideSuitability: 0.8,
            rainProbability: 0.2,
            hasStrongWarning: true
        )
        XCTAssertEqual(out.rating, .red)
        XCTAssertLessThanOrEqual(out.score, 30)
    }

    func testBoatDayScorerUsesSeaStateAndPlainMissingSignalCopy() {
        let out = BoatDayScorer.score(
            windKmh: nil,
            tideSuitability: 0.8,
            rainProbability: 0.1,
            hasStrongWarning: false,
            waveHeightM: 2.2
        )

        XCTAssertTrue(out.reasons.contains("Wind detail pending"))
        XCTAssertTrue(out.reasons.contains("Rough seas"))
        XCTAssertFalse(out.reasons.contains { $0.localizedCaseInsensitiveContains("signal limited") })
    }

    func testBoatDayScorerDoesNotAverageAwayRoughSeas() {
        let out = BoatDayScorer.score(
            windKmh: 10,
            tideSuitability: 0.9,
            rainProbability: 0.0,
            hasStrongWarning: false,
            waveHeightM: 2.0
        )

        XCTAssertEqual(out.rating, .red)
        XCTAssertLessThanOrEqual(out.score, 40)
    }
}
