import XCTest
@testable import BoatPleasantnessApp

final class BoatPleasantnessAppTests: XCTestCase {
    @MainActor
    func testLocationOverrideTakesPrecedence() {
        let defaults = UserDefaults(suiteName: "BoatPleasantnessAppTests")!
        defaults.removePersistentDomain(forName: "BoatPleasantnessAppTests")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))

        model.saveLocationOverride(name: "My Ramp", latitude: -30.1, longitude: 151.2)
        let location = model.effectiveLocation()

        XCTAssertEqual(location.name, "My Ramp")
        XCTAssertEqual(location.latitude, -30.1, accuracy: 0.0001)
    }

    @MainActor
    func testClearingOverrideFallsBackToPreset() {
        let defaults = UserDefaults(suiteName: "BoatPleasantnessAppTestsClear")!
        defaults.removePersistentDomain(forName: "BoatPleasantnessAppTestsClear")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.saveLocationOverride(name: "Manual", latitude: -30.1, longitude: 151.2)
        model.clearLocationOverride()

        let fallback = model.effectiveLocation()
        XCTAssertTrue(fallback.name.contains("Sydney"))
    }
}
