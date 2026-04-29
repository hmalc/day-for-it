import XCTest
@testable import dayforit
import WeatherCore

final class dayforitTests: XCTestCase {
    func testOpportunityClientIDPersistsAnonymously() {
        let defaults = UserDefaults(suiteName: "dayforitTestsOpportunityClientID")!
        defaults.removePersistentDomain(forName: "dayforitTestsOpportunityClientID")
        let store = OpportunityClientIDStore(defaults: defaults)

        let firstID = store.loadOrCreate()
        let secondID = store.loadOrCreate()

        XCTAssertFalse(firstID.isEmpty)
        XCTAssertEqual(firstID, secondID)
    }

    func testOpportunityRecommendationDecodesNullableArrays() throws {
        let json = """
        {
          "id": "rec_nullable",
          "activity": "picnic",
          "title": "Outdoor social window sunday morning",
          "description": "This looks like a comfortable outdoor social window.",
          "window": {
            "start": "2026-05-03T09:00:00+10:00",
            "end": "2026-05-03T12:00:00+10:00"
          },
          "priority": "high",
          "confidence": "medium",
          "verdict": "recommended",
          "final_score": 99.8,
          "suitability_score": 99.6,
          "opportunity_score": 100,
          "relevance_score": 100,
          "reasons": null,
          "risk_flags": null,
          "invalidation_conditions": null,
          "feedback_prompt": "Was this a good picnic or BBQ recommendation?",
          "scoring_version": "rules-v0.1.0"
        }
        """
        let recommendation = try Self.opportunityJSONDecoder.decode(
            OpportunityRecommendation.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(recommendation.reasons, [])
        XCTAssertEqual(recommendation.riskFlags, [])
        XCTAssertEqual(recommendation.invalidationConditions, [])
    }


    @MainActor
    func testOpportunityRefreshStoresRecommendations() async {
        let defaults = UserDefaults(suiteName: "dayforitTestsOpportunityRefresh")!
        defaults.removePersistentDomain(forName: "dayforitTestsOpportunityRefresh")
        let recommendation = Self.makeRecommendation(activity: "picnic", score: 91)
        let response = OpportunityScanResponse(
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            forecastSnapshotID: "forecast_test",
            recommendations: [recommendation],
            attribution: "Weather data by Open-Meteo"
        )
        let client = FakeOpportunityClient(response: response)
        let model = AppModel(
            opportunityClient: client,
            opportunityClientIDStore: OpportunityClientIDStore(defaults: defaults)
        )
        model.savedOverride = StoredLocation(
            name: "Brisbane",
            latitude: -27.4698,
            longitude: 153.0251,
            timeZoneID: "Australia/Brisbane"
        )

        await model.refreshOpportunities()

        XCTAssertEqual(model.opportunityRecommendations, [recommendation])
        XCTAssertEqual(model.opportunityAttribution, "Weather data by Open-Meteo")
        XCTAssertEqual(client.scannedLocation?.name, "Brisbane")
        XCTAssertEqual(Set(client.scannedInterests ?? []), Set(OpportunityActivity.all.map(\.id)))
        XCTAssertFalse(client.scannedClientID?.isEmpty ?? true)
    }

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

    private static func makeRecommendation(activity: String, score: Double) -> OpportunityRecommendation {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return OpportunityRecommendation(
            id: "rec_test",
            activity: activity,
            title: "Friday evening is your best BBQ window",
            description: "Low wind and low rain risk make this the clearest outdoor window.",
            window: .init(start: start, end: start.addingTimeInterval(3 * 60 * 60)),
            priority: "high",
            confidence: "medium",
            verdict: "recommended",
            finalScore: score,
            suitabilityScore: 92,
            opportunityScore: 88,
            relevanceScore: 100,
            reasons: ["Low rain risk", "Comfortable temperature"],
            riskFlags: [],
            invalidationConditions: [],
            feedbackPrompt: "Was this a good recommendation?",
            scoringVersion: "rules-v0.1.0"
        )
    }

    private static let opportunityJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(raw)")
        }
        return decoder
    }()
}

private final class FakeOpportunityClient: OpportunityClientProtocol {
    let response: OpportunityScanResponse
    private(set) var scannedLocation: MarineLocation?
    private(set) var scannedClientID: String?
    private(set) var scannedInterests: [String]?
    private(set) var feedback: OpportunityFeedback?

    init(response: OpportunityScanResponse) {
        self.response = response
    }

    func scan(location: MarineLocation, clientID: String, interests: [String]) async throws -> OpportunityScanResponse {
        scannedLocation = location
        scannedClientID = clientID
        scannedInterests = interests
        return response
    }

    func submitFeedback(recommendationID: String, clientID: String, feedback: OpportunityFeedback) async throws {
        self.feedback = feedback
    }
}
