import XCTest
@testable import dayforit
import PleasantnessEngine
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

    @MainActor
    func testHeroLeadsWithBestVerdictDay() {
        let defaults = UserDefaults(suiteName: "dayforitTestsHeroBest")!
        defaults.removePersistentDomain(forName: "dayforitTestsHeroBest")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.output = Self.makeOutput(verdicts: [.poor, .dayForIt, .decent, .ifYouMust])

        let hero = model.heroOpportunitySummary

        XCTAssertEqual(hero.tone, .dayForIt)
        XCTAssertEqual(hero.badgeText, "DAY FOR IT")
        XCTAssertEqual(hero.headline, "Tomorrow is a day for it")
    }

    @MainActor
    func testHeroHoldsOffWhenWeekIsPoor() {
        let defaults = UserDefaults(suiteName: "dayforitTestsHeroPoor")!
        defaults.removePersistentDomain(forName: "dayforitTestsHeroPoor")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.output = Self.makeOutput(verdicts: [.poor, .notAChance, .poor, .poor])

        let hero = model.heroOpportunitySummary

        XCTAssertEqual(hero.tone, .poor)
        XCTAssertEqual(hero.headline, "Hold off for now")
        XCTAssertTrue(hero.subheadline.contains("fresh winds"))
    }

    @MainActor
    func testHeroChecksWhileNothingIsCalled() {
        let defaults = UserDefaults(suiteName: "dayforitTestsHeroEmpty")!
        defaults.removePersistentDomain(forName: "dayforitTestsHeroEmpty")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))

        let hero = model.heroOpportunitySummary

        XCTAssertNil(hero.tone)
        XCTAssertEqual(hero.badgeText, "CHECKING")
    }

    @MainActor
    func testDetailPagesMarkBestDayOnlyWhenDecentOrBetter() {
        let defaults = UserDefaults(suiteName: "dayforitTestsBestDay")!
        defaults.removePersistentDomain(forName: "dayforitTestsBestDay")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.output = Self.makeOutput(verdicts: [.poor, .ifYouMust, .poor, .poor])

        XCTAssertFalse(model.fourDayDetailPages.contains(where: \.isBest))

        model.output = Self.makeOutput(verdicts: [.poor, .decent, .poor, .poor])
        XCTAssertEqual(model.fourDayDetailPages.first(where: \.isBest)?.dayLabel, "Tomorrow")
    }

    func testAlertPlannerNotifiesOnlyNewDayForItDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let inTwoDays = calendar.date(byAdding: .day, value: 2, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let daily = [
            makeDay(dayStart: yesterday, verdict: .dayForIt),   // past: ignored
            makeDay(dayStart: today, verdict: .poor),           // not a day for it
            makeDay(dayStart: inTwoDays, verdict: .dayForIt),   // new: notify
        ]

        let plans = DayForItAlertPlanner.plans(
            daily: daily,
            locationName: "Cowley Beach",
            alreadyNotified: [],
            now: Date(),
            calendar: calendar
        )

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.dayStart, inTwoDays)
        XCTAssertTrue(plans.first?.title.hasSuffix("is a day for it") == true)
        XCTAssertTrue(plans.first?.body.contains("Cowley Beach") == true)
        XCTAssertTrue(plans.first?.body.contains("Glassy seas") == true)
    }

    func testAlertPlannerSkipsAlreadyNotifiedDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let inTwoDays = calendar.date(byAdding: .day, value: 2, to: today)!
        let daily = [makeDay(dayStart: inTwoDays, verdict: .dayForIt)]
        let key = DayForItAlertPlanner.notificationKey(dayStart: inTwoDays, locationName: "Cowley Beach")

        let plans = DayForItAlertPlanner.plans(
            daily: daily,
            locationName: "Cowley Beach",
            alreadyNotified: [key],
            now: Date(),
            calendar: calendar
        )

        XCTAssertTrue(plans.isEmpty)
    }

    func testAlertPlannerTitlesTodayDistinctly() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daily = [makeDay(dayStart: today, verdict: .dayForIt)]

        let plans = DayForItAlertPlanner.plans(
            daily: daily,
            locationName: "Cowley Beach",
            alreadyNotified: [],
            now: Date(),
            calendar: calendar
        )

        XCTAssertEqual(plans.first?.title, "Today's a day for it")
    }

    func testAlertLedgerPrunesPastDays() {
        let defaults = UserDefaults(suiteName: "dayforitTestsAlertLedger")!
        defaults.removePersistentDomain(forName: "dayforitTestsAlertLedger")
        let ledger = DayForItAlertLedger(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pastKey = DayForItAlertPlanner.notificationKey(
            dayStart: calendar.date(byAdding: .day, value: -3, to: today)!,
            locationName: "Cowley Beach"
        )
        let futureKey = DayForItAlertPlanner.notificationKey(
            dayStart: calendar.date(byAdding: .day, value: 2, to: today)!,
            locationName: "Cowley Beach"
        )

        ledger.markNotified([pastKey, futureKey])

        XCTAssertEqual(ledger.notifiedKeys(), [futureKey])
    }

    private func makeDay(dayStart: Date, verdict: DayVerdict?) -> DailyMarineSummary {
        DailyMarineSummary(
            dayStart: dayStart,
            verdict: verdict,
            limitedBy: "Glassy seas (0.3 m)",
            confidence: "high",
            warningLimited: false,
            topDrivers: []
        )
    }

    private static func makeOutput(verdicts: [DayVerdict?]) -> MarineForecastOutput {
        let today = Calendar.current.startOfDay(for: Date())
        let daily = verdicts.enumerated().compactMap { offset, verdict -> DailyMarineSummary? in
            guard let dayStart = Calendar.current.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DailyMarineSummary(
                dayStart: dayStart,
                verdict: verdict,
                limitedBy: verdict == .dayForIt ? "Glassy seas (0.3 m)" : "Fresh winds (~40 km/h)",
                confidence: "high",
                warningLimited: false,
                topDrivers: ["Forecast wind up to 12 km/h", "Forecast seas 0.4 m"]
            )
        }
        return MarineForecastOutput(
            location: MarineLocation(name: "Test Coast", latitude: -17.6, longitude: 146.1, timeZoneID: "Australia/Brisbane"),
            generatedAt: Date(),
            daily: daily,
            warnings: [],
            dataQuality: .official,
            degradedReason: nil
        )
    }

}
