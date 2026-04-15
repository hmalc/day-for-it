import Foundation

public enum DataState: Sendable, Equatable {
    case available
    case missing
    case notProvided
    case unknown
}

public enum FreshnessStatus: Sendable, Equatable {
    case fresh
    case stale
    case unknown
}

public struct FieldValue<T: Sendable & Equatable>: Sendable, Equatable {
    public var value: T?
    public var state: DataState
    public var reason: String?

    public init(value: T?, state: DataState, reason: String? = nil) {
        self.value = value
        self.state = state
        self.reason = reason
    }
}

public struct ProvenanceRef: Sendable, Equatable {
    public var provider: String
    public var product: String
    public var sourceObjectID: String?
    public var fetchedAtUTC: Date
    public var parsedAtUTC: Date
    public var issuedAtUTC: Date?
    public var rawPayloadRef: String?

    public init(
        provider: String,
        product: String,
        sourceObjectID: String?,
        fetchedAtUTC: Date,
        parsedAtUTC: Date,
        issuedAtUTC: Date? = nil,
        rawPayloadRef: String? = nil
    ) {
        self.provider = provider
        self.product = product
        self.sourceObjectID = sourceObjectID
        self.fetchedAtUTC = fetchedAtUTC
        self.parsedAtUTC = parsedAtUTC
        self.issuedAtUTC = issuedAtUTC
        self.rawPayloadRef = rawPayloadRef
    }
}

public struct ValidityWindow: Sendable, Equatable {
    public var startUTC: Date
    public var endUTC: Date

    public init(startUTC: Date, endUTC: Date) {
        self.startUTC = startUTC
        self.endUTC = endUTC
    }
}

public struct ProviderBindings: Sendable, Equatable {
    public var bomCoastalAAC: String?
    public var bomObservationWMO: Int?
    public var bomMarineWarningPath: String?
    public var tideStationID: String?
    public var waveBuoyID: String?

    public init(
        bomCoastalAAC: String? = nil,
        bomObservationWMO: Int? = nil,
        bomMarineWarningPath: String? = nil,
        tideStationID: String? = nil,
        waveBuoyID: String? = nil
    ) {
        self.bomCoastalAAC = bomCoastalAAC
        self.bomObservationWMO = bomObservationWMO
        self.bomMarineWarningPath = bomMarineWarningPath
        self.tideStationID = tideStationID
        self.waveBuoyID = waveBuoyID
    }
}

public struct BoatingLocation: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneID: String
    public var bindings: ProviderBindings

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String,
        bindings: ProviderBindings = .init()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.bindings = bindings
    }
}

public struct MarineForecast: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var locationID: UUID
    public var validFor: ValidityWindow
    public var windSpeedKmh: FieldValue<Double>
    public var windGustKmh: FieldValue<Double>
    public var waveHeightM: FieldValue<Double>
    public var swellHeightM: FieldValue<Double>
    public var rainfallProb: FieldValue<Double>
    public var freshness: FreshnessStatus
    public var provenance: ProvenanceRef

    public init(
        id: UUID = UUID(),
        locationID: UUID,
        validFor: ValidityWindow,
        windSpeedKmh: FieldValue<Double>,
        windGustKmh: FieldValue<Double>,
        waveHeightM: FieldValue<Double>,
        swellHeightM: FieldValue<Double>,
        rainfallProb: FieldValue<Double>,
        freshness: FreshnessStatus = .unknown,
        provenance: ProvenanceRef
    ) {
        self.id = id
        self.locationID = locationID
        self.validFor = validFor
        self.windSpeedKmh = windSpeedKmh
        self.windGustKmh = windGustKmh
        self.waveHeightM = waveHeightM
        self.swellHeightM = swellHeightM
        self.rainfallProb = rainfallProb
        self.freshness = freshness
        self.provenance = provenance
    }
}

public struct MarineObservation: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var locationID: UUID
    public var observedAtUTC: Date
    public var windSpeedKmh: FieldValue<Double>
    public var windGustKmh: FieldValue<Double>
    public var waveHeightM: FieldValue<Double>
    public var seaTempC: FieldValue<Double>
    public var freshness: FreshnessStatus
    public var provenance: ProvenanceRef

    public init(
        id: UUID = UUID(),
        locationID: UUID,
        observedAtUTC: Date,
        windSpeedKmh: FieldValue<Double>,
        windGustKmh: FieldValue<Double>,
        waveHeightM: FieldValue<Double>,
        seaTempC: FieldValue<Double>,
        freshness: FreshnessStatus = .unknown,
        provenance: ProvenanceRef
    ) {
        self.id = id
        self.locationID = locationID
        self.observedAtUTC = observedAtUTC
        self.windSpeedKmh = windSpeedKmh
        self.windGustKmh = windGustKmh
        self.waveHeightM = waveHeightM
        self.seaTempC = seaTempC
        self.freshness = freshness
        self.provenance = provenance
    }
}

public enum TideEventKind: Sendable, Equatable {
    case high
    case low
}

public struct TideEvent: Sendable, Equatable {
    public var occurredAtUTC: Date
    public var kind: TideEventKind
    public var heightM: FieldValue<Double>

    public init(occurredAtUTC: Date, kind: TideEventKind, heightM: FieldValue<Double>) {
        self.occurredAtUTC = occurredAtUTC
        self.kind = kind
        self.heightM = heightM
    }
}

public struct TidePrediction: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var locationID: UUID
    public var window: ValidityWindow
    public var events: [TideEvent]
    public var suitability: FieldValue<Double>
    public var summary: String?
    public var freshness: FreshnessStatus
    public var provenance: ProvenanceRef

    public init(
        id: UUID = UUID(),
        locationID: UUID,
        window: ValidityWindow,
        events: [TideEvent],
        suitability: FieldValue<Double>,
        summary: String? = nil,
        freshness: FreshnessStatus = .unknown,
        provenance: ProvenanceRef
    ) {
        self.id = id
        self.locationID = locationID
        self.window = window
        self.events = events
        self.suitability = suitability
        self.summary = summary
        self.freshness = freshness
        self.provenance = provenance
    }
}

public struct WaveForecast: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var locationID: UUID
    public var validFor: ValidityWindow
    public var significantHeightM: FieldValue<Double>
    public var peakPeriodS: FieldValue<Double>
    public var directionDeg: FieldValue<Double>
    public var freshness: FreshnessStatus
    public var provenance: ProvenanceRef
}

public struct WaveObservation: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var locationID: UUID
    public var observedAtUTC: Date
    public var significantHeightM: FieldValue<Double>
    public var peakPeriodS: FieldValue<Double>
    public var directionDeg: FieldValue<Double>
    public var freshness: FreshnessStatus
    public var provenance: ProvenanceRef
}

public enum MarineWarningSeverity: Sendable, Equatable {
    case minor
    case strong
    case severe
}

public struct MarineWarning: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var locationID: UUID?
    public var headline: String
    public var severity: MarineWarningSeverity
    public var validWindow: ValidityWindow?
    public var issuedAtUTC: Date?
    public var freshness: FreshnessStatus
    public var provenance: ProvenanceRef

    public init(
        id: UUID = UUID(),
        locationID: UUID?,
        headline: String,
        severity: MarineWarningSeverity,
        validWindow: ValidityWindow?,
        issuedAtUTC: Date?,
        freshness: FreshnessStatus = .unknown,
        provenance: ProvenanceRef
    ) {
        self.id = id
        self.locationID = locationID
        self.headline = headline
        self.severity = severity
        self.validWindow = validWindow
        self.issuedAtUTC = issuedAtUTC
        self.freshness = freshness
        self.provenance = provenance
    }
}

public struct MarineSnapshot: Sendable, Equatable {
    public var locationID: UUID
    public var asOfUTC: Date
    public var forecast: [MarineForecast]
    public var observations: [MarineObservation]
    public var tides: [TidePrediction]
    public var waveForecasts: [WaveForecast]
    public var waveObservations: [WaveObservation]
    public var warnings: [MarineWarning]

    public init(
        locationID: UUID,
        asOfUTC: Date,
        forecast: [MarineForecast],
        observations: [MarineObservation],
        tides: [TidePrediction],
        waveForecasts: [WaveForecast],
        waveObservations: [WaveObservation],
        warnings: [MarineWarning]
    ) {
        self.locationID = locationID
        self.asOfUTC = asOfUTC
        self.forecast = forecast
        self.observations = observations
        self.tides = tides
        self.waveForecasts = waveForecasts
        self.waveObservations = waveObservations
        self.warnings = warnings
    }
}

public struct AssessmentInput: Sendable, Equatable {
    public var locationID: UUID
    public var targetWindow: ValidityWindow
    public var forecastWindKmh: FieldValue<Double>
    public var tideSuitability: FieldValue<Double>
    public var rainProbability: FieldValue<Double>
    public var warningSeverity: FieldValue<MarineWarningSeverity>
    public var provenanceRefs: [ProvenanceRef]

    public init(
        locationID: UUID,
        targetWindow: ValidityWindow,
        forecastWindKmh: FieldValue<Double>,
        tideSuitability: FieldValue<Double>,
        rainProbability: FieldValue<Double>,
        warningSeverity: FieldValue<MarineWarningSeverity>,
        provenanceRefs: [ProvenanceRef]
    ) {
        self.locationID = locationID
        self.targetWindow = targetWindow
        self.forecastWindKmh = forecastWindKmh
        self.tideSuitability = tideSuitability
        self.rainProbability = rainProbability
        self.warningSeverity = warningSeverity
        self.provenanceRefs = provenanceRefs
    }
}

public extension MarineLocation {
    func toBoatingLocation(feed: MarineFeedConfig) -> BoatingLocation {
        BoatingLocation(
            name: name,
            latitude: latitude,
            longitude: longitude,
            timeZoneID: timeZoneID,
            bindings: ProviderBindings(
                bomCoastalAAC: feed.preferredCoastalAAC,
                bomObservationWMO: feed.observationStationWMO,
                bomMarineWarningPath: feed.marineWarningRSSPath
            )
        )
    }
}
