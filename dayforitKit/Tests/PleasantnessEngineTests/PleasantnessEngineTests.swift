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
            hasStrongWarning: false,
            waveHeightM: 0.4
        )
        XCTAssertEqual(out.rating, .green)
        XCTAssertGreaterThan(out.score, 85)
    }

    func testBoatDayScorerRewardsGlassyFineWeatherGreatTide() {
        let out = BoatDayScorer.score(
            windKmh: 6,
            tideSuitability: 0.95,
            rainProbability: 0.0,
            hasStrongWarning: false,
            waveHeightM: 0.15,
            swellHeightM: 0.1
        )

        XCTAssertEqual(out.rating, .green)
        XCTAssertGreaterThanOrEqual(out.score, 98)
        XCTAssertTrue(out.reasons.contains("Glassy seas"))
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

    func testBoatDayScorerUsesSeaStateAndOmitsMissingSignalCopy() {
        let out = BoatDayScorer.score(
            windKmh: nil,
            tideSuitability: 0.8,
            rainProbability: 0.1,
            hasStrongWarning: false,
            waveHeightM: 2.0
        )

        XCTAssertTrue(out.reasons.contains("Rough seas"))
        XCTAssertFalse(out.reasons.contains { $0.localizedCaseInsensitiveContains("pending") })
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

    func testBoatDayScorerCapsLumpySeasBelowGreen() {
        let out = BoatDayScorer.score(
            windKmh: 8,
            tideSuitability: 0.95,
            rainProbability: 0.0,
            hasStrongWarning: false,
            waveHeightM: 1.45
        )

        XCTAssertEqual(out.rating, .amber)
        XCTAssertLessThanOrEqual(out.score, 68)
    }

    func testBoatDayScorerRequiresSeaStateForGreen() {
        let out = BoatDayScorer.score(
            windKmh: 6,
            tideSuitability: 0.95,
            rainProbability: 0.0,
            hasStrongWarning: false
        )

        XCTAssertNotEqual(out.rating, .green)
        XCTAssertLessThanOrEqual(out.score, 72)
    }

    func testPleasantnessEngineLetsSeaStateDominate() {
        let input = ScoringInput(
            windSpeedKmh: 8,
            seaHeightMetres: 1.9,
            swellHeightMetres: 1.2,
            rainProbability: 0.0,
            airTemperatureC: 24
        )

        let result = PleasantnessEngine.evaluate(input)

        XCTAssertLessThanOrEqual(result.index, 42)
        XCTAssertTrue(result.topDrivers.contains { $0.localizedCaseInsensitiveContains("Sea motion") })
    }
}
