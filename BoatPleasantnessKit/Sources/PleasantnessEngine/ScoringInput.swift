import Foundation

/// Normalized inputs for scoring. All optional fields reflect gaps in upstream data.
public struct ScoringInput: Sendable, Equatable {
    public struct MarineWarning: Sendable, Equatable {
        public var title: String
        public var severity: WarningSeverity

        public init(title: String, severity: WarningSeverity) {
            self.title = title
            self.severity = severity
        }
    }

    public enum WarningSeverity: Int, Sendable, Comparable {
        case advisory = 1
        case strong = 2
        case gale = 3
        case storm = 4

        public static func < (lhs: WarningSeverity, rhs: WarningSeverity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Best available sustained wind (km/h).
    public var windSpeedKmh: Double?
    /// Gusts if known (km/h).
    public var windGustKmh: Double?
    /// Max wind implied by coastal forecast text (km/h), if numeric parsing succeeded.
    public var coastalWindMaxKmh: Double?
    /// Roughness of seas in metres (estimated from text or model).
    public var seaHeightMetres: Double?
    /// Primary swell height in metres (estimated).
    public var swellHeightMetres: Double?
    /// Swell period seconds if known.
    public var swellPeriodSeconds: Double?
    /// 0...1 rain probability for the window.
    public var rainProbability: Double?
    /// 0...100 cloud cover.
    public var cloudCoverPercent: Double?
    public var visibilityKm: Double?
    public var airTemperatureC: Double?
    /// 0...11+ UV index.
    public var uvIndex: Double?
    public var activeWarnings: [MarineWarning]
    /// Keywords from synoptic / caution text (lowercased snippets).
    public var hazardKeywords: [String]

    public init(
        windSpeedKmh: Double? = nil,
        windGustKmh: Double? = nil,
        coastalWindMaxKmh: Double? = nil,
        seaHeightMetres: Double? = nil,
        swellHeightMetres: Double? = nil,
        swellPeriodSeconds: Double? = nil,
        rainProbability: Double? = nil,
        cloudCoverPercent: Double? = nil,
        visibilityKm: Double? = nil,
        airTemperatureC: Double? = nil,
        uvIndex: Double? = nil,
        activeWarnings: [MarineWarning] = [],
        hazardKeywords: [String] = []
    ) {
        self.windSpeedKmh = windSpeedKmh
        self.windGustKmh = windGustKmh
        self.coastalWindMaxKmh = coastalWindMaxKmh
        self.seaHeightMetres = seaHeightMetres
        self.swellHeightMetres = swellHeightMetres
        self.swellPeriodSeconds = swellPeriodSeconds
        self.rainProbability = rainProbability
        self.cloudCoverPercent = cloudCoverPercent
        self.visibilityKm = visibilityKm
        self.airTemperatureC = airTemperatureC
        self.uvIndex = uvIndex
        self.activeWarnings = activeWarnings
        self.hazardKeywords = hazardKeywords
    }
}
