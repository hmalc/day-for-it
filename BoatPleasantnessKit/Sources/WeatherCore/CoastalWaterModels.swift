import Foundation

public struct CoastalForecastDocument: Sendable, Equatable {
    public var productId: String
    public var issueTimeUTC: Date?
    public var areas: [CoastalArea]

    public init(productId: String, issueTimeUTC: Date?, areas: [CoastalArea]) {
        self.productId = productId
        self.issueTimeUTC = issueTimeUTC
        self.areas = areas
    }
}

public struct CoastalArea: Sendable, Equatable {
    public var aac: String
    public var description: String
    public var areaType: String
    public var periods: [CoastalPeriod]

    public init(aac: String, description: String, areaType: String, periods: [CoastalPeriod]) {
        self.aac = aac
        self.description = description
        self.areaType = areaType
        self.periods = periods
    }
}

public struct CoastalPeriod: Sendable, Equatable {
    public var index: Int?
    public var startUTC: Date?
    public var endUTC: Date?
    public var forecastWinds: String?
    public var forecastSeas: String?
    public var forecastSwell1: String?
    public var forecastSwell2: String?
    public var forecastWeather: String?
    public var forecastCaution: String?
    public var synopticSituation: String?
    public var preamble: String?

    public init(
        index: Int? = nil,
        startUTC: Date? = nil,
        endUTC: Date? = nil,
        forecastWinds: String? = nil,
        forecastSeas: String? = nil,
        forecastSwell1: String? = nil,
        forecastSwell2: String? = nil,
        forecastWeather: String? = nil,
        forecastCaution: String? = nil,
        synopticSituation: String? = nil,
        preamble: String? = nil
    ) {
        self.index = index
        self.startUTC = startUTC
        self.endUTC = endUTC
        self.forecastWinds = forecastWinds
        self.forecastSeas = forecastSeas
        self.forecastSwell1 = forecastSwell1
        self.forecastSwell2 = forecastSwell2
        self.forecastWeather = forecastWeather
        self.forecastCaution = forecastCaution
        self.synopticSituation = synopticSituation
        self.preamble = preamble
    }
}
