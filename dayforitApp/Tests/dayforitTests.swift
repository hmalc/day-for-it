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
          "activity": "boating",
          "title": "Day for it: Sunday morning",
          "description": "This looks like a calm boating window.",
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
          "feedback_prompt": "Was this a good boating recommendation?",
          "scoring_version": "rules-v0.2.0",
          "decision_label": "day_for_it",
          "analysis": {
            "band": "day_for_it",
            "summary": "Glassier than the surrounding windows.",
            "factors": [
              {
                "id": "wind",
                "label": "Wind",
                "score": 95,
                "detail": "Light winds hold through the morning."
              }
            ],
            "data_signals": null,
            "source_status": null
          }
        }
        """
        let recommendation = try Self.opportunityJSONDecoder.decode(
            OpportunityRecommendation.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(recommendation.reasons, [])
        XCTAssertEqual(recommendation.riskFlags, [])
        XCTAssertEqual(recommendation.invalidationConditions, [])
        XCTAssertEqual(recommendation.decisionLabel, "day_for_it")
        XCTAssertEqual(recommendation.analysis?.band, "day_for_it")
        XCTAssertEqual(recommendation.analysis?.summary, "Glassier than the surrounding windows.")
        XCTAssertEqual(recommendation.analysis?.factors.first?.label, "Wind")
        XCTAssertEqual(recommendation.analysis?.dataSignals, [])
        XCTAssertEqual(recommendation.analysis?.sourceStatus, [])
    }

    func testDecisionSummaryGeneratorParsesHeadlineAndSummary() {
        let copy = DecisionSummaryGenerator.parseCopy("""
        Headline: Wave/swell window Sunday
        Summary: Sunday morning has low wave height, low swell, light wind, and usable tides, but still check warnings before leaving.
        """)

        XCTAssertEqual(copy?.headline, "Wave/swell window Sunday")
        XCTAssertEqual(copy?.summary, "Sunday morning has low wave height, low swell, light wind, and usable tides, but still check warnings before leaving.")
    }


    @MainActor
    func testOpportunityRefreshStoresRecommendations() async {
        let defaults = UserDefaults(suiteName: "dayforitTestsOpportunityRefresh")!
        defaults.removePersistentDomain(forName: "dayforitTestsOpportunityRefresh")
        let recommendation = Self.makeRecommendation(activity: "boating", score: 91)
        let response = OpportunityScanResponse(
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            forecastStart: nil,
            forecastEnd: nil,
            forecastDays: 10,
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
        XCTAssertEqual(Set(client.scannedInterests ?? []), Set(OpportunityActivity.clientAnchorIDs))
        XCTAssertFalse(client.scannedClientID?.isEmpty ?? true)
    }

    @MainActor
    func testOpportunityRefreshSuppressesNightBoatingWindows() async {
        let defaults = UserDefaults(suiteName: "dayforitTestsNightBoatingWindow")!
        defaults.removePersistentDomain(forName: "dayforitTestsNightBoatingWindow")
        let nightStart = Self.testDate(year: 2026, month: 5, day: 1, hour: 22)
        let recommendation = Self.makeRecommendation(activity: "boating", score: 94, start: nightStart)
        let response = OpportunityScanResponse(
            fetchedAt: Self.testDate(year: 2026, month: 5, day: 1, hour: 8),
            forecastStart: nil,
            forecastEnd: nil,
            forecastDays: 10,
            forecastSnapshotID: "forecast_test",
            recommendations: [recommendation],
            attribution: "Weather data by Open-Meteo"
        )
        let model = AppModel(
            opportunityClient: FakeOpportunityClient(response: response),
            opportunityClientIDStore: OpportunityClientIDStore(defaults: defaults)
        )

        await model.refreshOpportunities()

        XCTAssertTrue(model.opportunityRecommendations.isEmpty)
    }

    @MainActor
    func testOpportunityRefreshClearsStaleRecommendationsOnFailure() async {
        let defaults = UserDefaults(suiteName: "dayforitTestsOpportunityRefreshFailure")!
        defaults.removePersistentDomain(forName: "dayforitTestsOpportunityRefreshFailure")
        let staleRecommendation = Self.makeRecommendation(activity: "boating", score: 91)
        let model = AppModel(
            opportunityClient: ThrowingOpportunityClient(),
            opportunityClientIDStore: OpportunityClientIDStore(defaults: defaults)
        )
        model.opportunityRecommendations = [staleRecommendation]
        model.opportunityAttribution = "stale attribution"
        model.opportunityFetchedAt = Date()

        await model.refreshOpportunities(clearsExistingData: true)

        XCTAssertTrue(model.opportunityRecommendations.isEmpty)
        XCTAssertNil(model.opportunityAttribution)
        XCTAssertNil(model.opportunityFetchedAt)
        XCTAssertNotNil(model.opportunityErrorMessage)
    }

    @MainActor
    func testHeroSummaryPrefersBackendBoatingDecision() {
        let defaults = UserDefaults(suiteName: "dayforitTestsBackendHero")!
        defaults.removePersistentDomain(forName: "dayforitTestsBackendHero")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.opportunityRecommendations = [
            Self.makeRecommendation(
                activity: "boating",
                score: 93,
                title: "Day for it: Saturday morning",
                description: "This is the calmest boating window currently showing.",
                decisionLabel: "day_for_it",
                analysis: OpportunityAnalysis(
                    band: "day_for_it",
                    summary: "The backend sees a rare calm window with low wind and low swell.",
                    factors: [
                        OpportunityScoreFactor(
                            id: "wind",
                            label: "Wind",
                            score: 96,
                            detail: "Light winds hold through the morning."
                        )
                    ],
                    dataSignals: ["Wave data available"],
                    sourceStatus: []
                )
            )
        ]

        let summary = model.heroOpportunitySummary

        XCTAssertEqual(summary.headline, "Day for it: Saturday morning")
        XCTAssertEqual(summary.badgeText, "DAY FOR IT")
        XCTAssertEqual(summary.tone, .green)
        XCTAssertTrue(summary.subheadline.contains("rare calm window"))
        XCTAssertTrue(summary.focusDrivers.contains { $0.contains("Light winds") })
    }

    @MainActor
    func testWindLedWatchDoesNotLookSeaConfirmed() {
        let defaults = UserDefaults(suiteName: "dayforitTestsWindWatchEvidence")!
        defaults.removePersistentDomain(forName: "dayforitTestsWindWatchEvidence")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.opportunityRecommendations = [
            Self.makeRecommendation(
                activity: "boating",
                score: 71,
                title: "Wind watch: Tuesday morning",
                description: "Projected wind is low enough to watch.",
                decisionLabel: "wind_led_watch",
                analysis: OpportunityAnalysis(
                    band: "wind_led_watch",
                    summary: "Wind-only watch: projected wind is low, but wave height and swell need to confirm.",
                    factors: [
                        OpportunityScoreFactor(
                            id: "sea_motion",
                            label: "Sea motion",
                            score: 100,
                            detail: "Sea state estimated from wind (no explicit seas height yet)."
                        ),
                        OpportunityScoreFactor(
                            id: "wind_comfort",
                            label: "Wind comfort",
                            score: 98,
                            detail: "About 4 km/h sustained."
                        )
                    ],
                    dataSignals: ["wind 4 km/h", "gust 13 km/h"],
                    sourceStatus: [
                        "wave_height_metres: missing",
                        "swell_height_metres: missing"
                    ]
                )
            )
        ]

        XCTAssertEqual(model.heroOpportunitySummary.badgeText, "WIND WATCH")
        XCTAssertEqual(model.heroWavesText, "Not confirmed")
        XCTAssertFalse(model.marineEvidenceStatus.isConfirmed)
        XCTAssertEqual(model.marineEvidenceStatus.title, "Wave/swell missing")
        XCTAssertTrue(model.marineEvidenceStatus.detail.contains("candidate signal"))
    }

    @MainActor
    func testKnownSeaDataIsPromotedAsPrimaryEvidence() {
        let defaults = UserDefaults(suiteName: "dayforitTestsSeaEvidence")!
        defaults.removePersistentDomain(forName: "dayforitTestsSeaEvidence")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        model.opportunityRecommendations = [
            Self.makeRecommendation(
                activity: "boating",
                score: 92,
                title: "Day for it: Sunday morning",
                description: "Low wind and low sea-state window.",
                decisionLabel: "day_for_it",
                analysis: OpportunityAnalysis(
                    band: "day_for_it",
                    summary: "Ideal boating candidate with sea data confirmed.",
                    factors: [
                        OpportunityScoreFactor(
                            id: "sea_motion",
                            label: "Sea motion",
                            score: 94,
                            detail: "Roughness index ~0.4 m from seas and swell."
                        ),
                        OpportunityScoreFactor(
                            id: "wind_comfort",
                            label: "Wind comfort",
                            score: 95,
                            detail: "About 8 km/h sustained."
                        )
                    ],
                    dataSignals: ["wave 0.3 m", "swell 0.4 m", "period 10 s"],
                    sourceStatus: ["open-meteo-marine: ok"]
                )
            )
        ]

        XCTAssertTrue(model.marineEvidenceStatus.isConfirmed)
        XCTAssertEqual(model.marineEvidenceStatus.title, "Wave + swell + period")
        XCTAssertTrue(model.marineEvidenceStatus.detail.contains("wave 0.3 m"))
        XCTAssertEqual(model.heroWavesText, "0.4 m")
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

    @MainActor
    func testTideEventsExposeAllHighsAndLowsInCurrentWindow() {
        let defaults = UserDefaults(suiteName: "dayforitTestsAllTideEvents")!
        defaults.removePersistentDomain(forName: "dayforitTestsAllTideEvents")
        let model = AppModel(locationStore: LocationStore(defaults: defaults))
        let calendar = Calendar.current
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        model.tideForecast = TideForecast(
            generatedAt: now,
            provider: "Test",
            locationName: "Test",
            chartMaximumMeters: 3.2,
            days: [
                TideDayForecast(
                    dayStart: dayStart,
                    events: [
                        TideEventPoint(time: dayStart.addingTimeInterval(2 * 60 * 60), kind: .low, heightMeters: 0.4, source: .authoritative),
                        TideEventPoint(time: dayStart.addingTimeInterval(6 * 60 * 60), kind: .high, heightMeters: 2.1, source: .authoritative),
                        TideEventPoint(time: dayStart.addingTimeInterval(12 * 60 * 60), kind: .low, heightMeters: 0.5, source: .authoritative),
                        TideEventPoint(time: dayStart.addingTimeInterval(18 * 60 * 60), kind: .high, heightMeters: 2.0, source: .authoritative)
                    ],
                    samples: []
                )
            ]
        )

        let events = model.tideEvents
        let tidePage = model.tideCardViewData

        XCTAssertEqual(events.count, 4)
        XCTAssertTrue(events[0].contains("Low"))
        XCTAssertTrue(events[1].contains("High"))
        XCTAssertTrue(events[2].contains("Low"))
        XCTAssertTrue(events[3].contains("High"))
        XCTAssertEqual(tidePage.axisStart, dayStart)
        XCTAssertEqual(tidePage.axisEnd, calendar.date(byAdding: .day, value: 1, to: dayStart))
        XCTAssertEqual(tidePage.windowLabel, "Midnight to midnight")
        XCTAssertEqual(tidePage.chartMaximumMeters, 3.2)
    }

    func testBoatingAlertPolicyAcceptsHighConfidenceConfirmedSeaWeekendWindow() {
        let now = Self.testDate(year: 2026, month: 5, day: 1, hour: 6)
        let recommendation = Self.makeRecommendation(
            activity: "boating",
            score: 78,
            title: "Day for it: Saturday morning",
            decisionLabel: "day_for_it",
            analysis: Self.confirmedSeaAnalysis(),
            start: Self.testDate(year: 2026, month: 5, day: 2, hour: 9),
            confidence: "high"
        )

        let candidate = BoatingAlertPolicy.bestAlertCandidate(
            in: [recommendation],
            location: Self.cowleyBeach,
            now: now,
            calendar: Self.brisbaneCalendar
        )

        XCTAssertEqual(candidate, recommendation)
    }

    func testBoatingAlertPolicySuppressesMediumConfidenceWindow() {
        let now = Self.testDate(year: 2026, month: 5, day: 1, hour: 6)
        let recommendation = Self.makeRecommendation(
            activity: "boating",
            score: 96,
            decisionLabel: "day_for_it",
            analysis: Self.confirmedSeaAnalysis(),
            start: Self.testDate(year: 2026, month: 5, day: 2, hour: 9),
            confidence: "medium"
        )

        XCTAssertFalse(BoatingAlertPolicy.shouldAlert(for: recommendation, location: Self.cowleyBeach, now: now, calendar: Self.brisbaneCalendar))
    }

    func testBoatingAlertPolicySuppressesWindOnlyWatch() {
        let now = Self.testDate(year: 2026, month: 5, day: 1, hour: 6)
        let recommendation = Self.makeRecommendation(
            activity: "boating",
            score: 96,
            decisionLabel: "wind_led_watch",
            analysis: OpportunityAnalysis(
                band: "wind_led_watch",
                summary: "Projected wind is low, but wave height and swell need to confirm.",
                factors: [
                    OpportunityScoreFactor(
                        id: "sea_motion",
                        label: "Sea motion",
                        score: 96,
                        detail: "Sea state estimated from wind (no explicit seas height yet)."
                    )
                ],
                dataSignals: ["wind 4 km/h", "gust 10 km/h"],
                sourceStatus: [
                    "wave_height_metres: missing",
                    "swell_height_metres: missing"
                ]
            ),
            start: Self.testDate(year: 2026, month: 5, day: 2, hour: 9),
            confidence: "high"
        )

        XCTAssertFalse(BoatingAlertPolicy.shouldAlert(for: recommendation, location: Self.cowleyBeach, now: now, calendar: Self.brisbaneCalendar))
    }

    func testBoatingAlertPolicySuppressesWatchBandEvenWithSeaData() {
        let now = Self.testDate(year: 2026, month: 5, day: 1, hour: 6)
        let recommendation = Self.makeRecommendation(
            activity: "boating",
            score: 95,
            decisionLabel: "worth_watching",
            analysis: OpportunityAnalysis(
                band: "worth_watching",
                summary: "Sea data is present, but this is still a watch rather than a clean day-for-it call.",
                factors: Self.confirmedSeaAnalysis().factors,
                dataSignals: ["wave 0.3 m", "swell 0.4 m"],
                sourceStatus: ["open-meteo-marine: ok"]
            ),
            start: Self.testDate(year: 2026, month: 5, day: 2, hour: 9),
            confidence: "high"
        )

        XCTAssertFalse(BoatingAlertPolicy.shouldAlert(for: recommendation, location: Self.cowleyBeach, now: now, calendar: Self.brisbaneCalendar))
    }

    func testBoatingAlertPolicySuppressesRegularWeekdayWindow() {
        let now = Self.testDate(year: 2026, month: 5, day: 4, hour: 18)
        let recommendation = Self.makeRecommendation(
            activity: "boating",
            score: 94,
            decisionLabel: "day_for_it",
            analysis: Self.confirmedSeaAnalysis(),
            start: Self.testDate(year: 2026, month: 5, day: 5, hour: 9),
            confidence: "high"
        )

        XCTAssertFalse(BoatingAlertPolicy.shouldAlert(for: recommendation, location: Self.cowleyBeach, now: now, calendar: Self.brisbaneCalendar))
    }

    func testBoatingAlertPolicyAcceptsQueenslandPublicHolidayWindow() {
        let now = Self.testDate(year: 2026, month: 5, day: 1, hour: 6)
        let recommendation = Self.makeRecommendation(
            activity: "boating",
            score: 82,
            decisionLabel: "day_for_it",
            analysis: Self.confirmedSeaAnalysis(),
            start: Self.testDate(year: 2026, month: 5, day: 4, hour: 9),
            confidence: "high"
        )

        XCTAssertTrue(BoatingAlertPolicy.shouldAlert(for: recommendation, location: Self.cowleyBeach, now: now, calendar: Self.brisbaneCalendar))
    }

    func testBoatingAlertSchedulerUsesWakingHourAnchors() {
        let afterMorningCheck = Self.testDate(year: 2026, month: 5, day: 1, hour: 8)
        let afterLastCheck = Self.testDate(year: 2026, month: 5, day: 1, hour: 18)

        let midday = BoatingAlertScheduler.nextCheckDate(after: afterMorningCheck, calendar: Self.brisbaneCalendar)
        let tomorrowMorning = BoatingAlertScheduler.nextCheckDate(after: afterLastCheck, calendar: Self.brisbaneCalendar)

        XCTAssertEqual(Self.brisbaneCalendar.component(.hour, from: midday), 12)
        XCTAssertEqual(Self.brisbaneCalendar.component(.hour, from: tomorrowMorning), 7)
        XCTAssertTrue(Self.brisbaneCalendar.isDate(tomorrowMorning, inSameDayAs: Self.testDate(year: 2026, month: 5, day: 2, hour: 7)))
    }

    private static func makeRecommendation(
        activity: String,
        score: Double,
        title: String = "Friday evening is your best BBQ window",
        description: String = "Low wind and low rain risk make this the clearest outdoor window.",
        decisionLabel: String? = nil,
        analysis: OpportunityAnalysis? = nil,
        start: Date = testDate(year: 2026, month: 5, day: 1, hour: 9),
        priority: String = "high",
        confidence: String = "medium"
    ) -> OpportunityRecommendation {
        return OpportunityRecommendation(
            id: "rec_test",
            activity: activity,
            title: title,
            description: description,
            window: .init(start: start, end: start.addingTimeInterval(3 * 60 * 60)),
            priority: priority,
            confidence: confidence,
            verdict: "recommended",
            finalScore: score,
            suitabilityScore: 92,
            opportunityScore: 88,
            relevanceScore: 100,
            reasons: ["Low rain risk", "Comfortable temperature"],
            riskFlags: [],
            invalidationConditions: [],
            feedbackPrompt: "Was this a good recommendation?",
            scoringVersion: "rules-v0.1.0",
            decisionLabel: decisionLabel,
            analysis: analysis
        )
    }

    private static func confirmedSeaAnalysis() -> OpportunityAnalysis {
        OpportunityAnalysis(
            band: "day_for_it",
            summary: "Confirmed low wave height and swell with light wind.",
            factors: [
                OpportunityScoreFactor(
                    id: "sea_motion",
                    label: "Sea motion",
                    score: 96,
                    detail: "Roughness index ~0.3 m from seas and swell."
                ),
                OpportunityScoreFactor(
                    id: "wind_comfort",
                    label: "Wind comfort",
                    score: 95,
                    detail: "About 7 km/h sustained."
                )
            ],
            dataSignals: ["wave 0.2 m", "swell 0.3 m", "period 10 s"],
            sourceStatus: ["open-meteo-marine: ok"]
        )
    }

    private static func testDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        brisbaneCalendar.date(from: DateComponents(
            timeZone: brisbaneCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private static var brisbaneCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Brisbane")!
        return calendar
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

    private static let cowleyBeach = MarineLocation(
        name: "Cowley Beach",
        latitude: -17.679,
        longitude: 146.112,
        timeZoneID: "Australia/Brisbane"
    )
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

private struct ThrowingOpportunityClient: OpportunityClientProtocol {
    func scan(location: MarineLocation, clientID: String, interests: [String]) async throws -> OpportunityScanResponse {
        throw URLError(.cannotLoadFromNetwork)
    }

    func submitFeedback(recommendationID: String, clientID: String, feedback: OpportunityFeedback) async throws {}
}
