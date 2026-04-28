import XCTest
@testable import dayforit
import WeatherCore

final class dayforitTests: XCTestCase {
    @MainActor
    func testLocationOverrideTakesPrecedence() {
        let defaults = UserDefaults(suiteName: "dayforitTests")!
        defaults.removePersistentDomain(forName: "dayforitTests")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))

        model.saveLocationOverride(name: "My Ramp", latitude: -30.1, longitude: 151.2)
        let location = model.effectiveLocation()

        XCTAssertEqual(location.name, "My Ramp")
        XCTAssertEqual(location.latitude, -30.1, accuracy: 0.0001)
    }

    @MainActor
    func testClearingOverrideFallsBackToPreset() {
        let defaults = UserDefaults(suiteName: "dayforitTestsClear")!
        defaults.removePersistentDomain(forName: "dayforitTestsClear")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.saveLocationOverride(name: "Manual", latitude: -30.1, longitude: 151.2)
        model.clearLocationOverride()

        let fallback = model.effectiveLocation()
        XCTAssertEqual(fallback.name, "Cowley Beach")
        XCTAssertEqual(fallback.latitude, -17.679, accuracy: 0.0001)
        XCTAssertEqual(fallback.longitude, 146.112, accuracy: 0.0001)
    }

    @MainActor
    func testCowleyBeachUsesNearbyObservationStation() {
        let defaults = UserDefaults(suiteName: "dayforitTestsCowleyFeed")!
        defaults.removePersistentDomain(forName: "dayforitTestsCowleyFeed")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))

        let feed = model.effectiveFeedConfig()

        XCTAssertEqual(feed.observationProductID, "IDQ60801")
        XCTAssertEqual(feed.observationStationWMO, 94280)
    }

    @MainActor
    func testSydneyPresetUsesForecastOnlyNSWFeed() {
        let defaults = UserDefaults(suiteName: "dayforitTestsSydneyFeed")!
        defaults.removePersistentDomain(forName: "dayforitTestsSydneyFeed")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        let preset = LocationPreset.forecastOnly.first { $0.id == "sydney-harbour" }!

        model.savedOverride = preset.storedLocation
        let location = model.effectiveLocation()
        let feed = model.effectiveFeedConfig()

        XCTAssertEqual(location.timeZoneID, "Australia/Sydney")
        XCTAssertEqual(feed.coastalProductID, "IDN11001")
        XCTAssertEqual(feed.observationProductID, "IDN60801")
        XCTAssertEqual(feed.observationStationWMO, 95766)
        XCTAssertEqual(feed.marineWarningRSSPath, "/fwo/IDZ00068.warnings_marine_nsw.xml")
        XCTAssertEqual(feed.preferredCoastalAAC, "NSW_MW004")
    }

    @MainActor
    func testByronPresetStaysOnNSWFeed() {
        let defaults = UserDefaults(suiteName: "dayforitTestsByronFeed")!
        defaults.removePersistentDomain(forName: "dayforitTestsByronFeed")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        let preset = LocationPreset.forecastOnly.first { $0.id == "byron-bay" }!

        model.savedOverride = preset.storedLocation
        let feed = model.effectiveFeedConfig()

        XCTAssertEqual(feed.coastalProductID, "IDN11001")
        XCTAssertEqual(feed.observationStationWMO, 94599)
        XCTAssertEqual(feed.preferredCoastalAAC, "NSW_MW008")
    }

    @MainActor
    func testManualLocationSupportStaysConservative() {
        let defaults = UserDefaults(suiteName: "dayforitTestsCoverage")!
        defaults.removePersistentDomain(forName: "dayforitTestsCoverage")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))

        XCTAssertTrue(model.supportsManualLocation(latitude: -17.679, longitude: 146.112))
        XCTAssertTrue(model.supportsManualLocation(latitude: -33.843, longitude: 151.255))
        XCTAssertFalse(model.supportsManualLocation(latitude: -23.700, longitude: 133.880))
    }

    @MainActor
    func testFutureTidePagesUsePredictionLanguage() {
        let defaults = UserDefaults(suiteName: "dayforitTestsFutureTides")!
        defaults.removePersistentDomain(forName: "dayforitTestsFutureTides")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        let now = Date()
        let events = [
            TideEventPoint(
                time: now.addingTimeInterval(-60 * 60),
                kind: .low,
                heightMeters: 0.4,
                source: .authoritative
            ),
            TideEventPoint(
                time: now.addingTimeInterval(3 * 60 * 60),
                kind: .high,
                heightMeters: 2.1,
                source: .authoritative
            ),
            TideEventPoint(
                time: now.addingTimeInterval(27 * 60 * 60),
                kind: .high,
                heightMeters: 2.0,
                source: .authoritative
            ),
            TideEventPoint(
                time: now.addingTimeInterval(33 * 60 * 60),
                kind: .low,
                heightMeters: 0.5,
                source: .authoritative
            )
        ]
        model.tideForecast = TideForecast(
            generatedAt: now,
            provider: "Test",
            locationName: "Test",
            days: [
                TideDayForecast(dayStart: now, events: events, samples: [])
            ]
        )

        let pages = model.tidePageViewData
        XCTAssertEqual(pages.first?.stateLabel, "Rising tide")
        let futureLabel = pages[1].stateLabel.lowercased()
        XCTAssertTrue(futureLabel.contains("predicted"))
        XCTAssertFalse(futureLabel.contains("rising"))
        XCTAssertFalse(futureLabel.contains("falling"))
    }
}
