import Foundation
import PleasantnessEngine

public struct MarineLocation: Sendable, Equatable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneID: String

    public init(name: String, latitude: Double, longitude: Double, timeZoneID: String = "Australia/Sydney") {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
    }
}

public struct MarineFeedConfig: Sendable, Equatable {
    public var coastalProductID: String
    public var observationProductID: String
    public var observationStationWMO: Int
    public var marineWarningRSSPath: String
    public var preferredCoastalAAC: String?
    public var waveBuoyID: String?

    public init(
        coastalProductID: String,
        observationProductID: String,
        observationStationWMO: Int,
        marineWarningRSSPath: String,
        preferredCoastalAAC: String? = nil,
        waveBuoyID: String? = nil
    ) {
        self.coastalProductID = coastalProductID
        self.observationProductID = observationProductID
        self.observationStationWMO = observationStationWMO
        self.marineWarningRSSPath = marineWarningRSSPath
        self.preferredCoastalAAC = preferredCoastalAAC
        self.waveBuoyID = waveBuoyID
    }
}

public struct MarineForecastRequest: Sendable, Equatable {
    public var location: MarineLocation
    public var feed: MarineFeedConfig
    public var forecastDays: Int

    public init(location: MarineLocation, feed: MarineFeedConfig, forecastDays: Int = 7) {
        self.location = location
        self.feed = feed
        self.forecastDays = max(1, min(7, forecastDays))
    }
}

public struct DailyMarineSummary: Sendable, Equatable, Identifiable {
    public var id: Date { dayStart }
    public var dayStart: Date
    /// nil means there was no usable data to call the day.
    public var verdict: DayVerdict?
    /// The worst factor, when a verdict exists.
    public var limitedBy: String?
    public var confidence: String
    public var warningLimited: Bool
    public var topDrivers: [String]

    public init(
        dayStart: Date,
        verdict: DayVerdict?,
        limitedBy: String?,
        confidence: String,
        warningLimited: Bool,
        topDrivers: [String]
    ) {
        self.dayStart = dayStart
        self.verdict = verdict
        self.limitedBy = limitedBy
        self.confidence = confidence
        self.warningLimited = warningLimited
        self.topDrivers = topDrivers
    }
}

public struct MarineForecastOutput: Sendable, Equatable {
    public enum DataQuality: String, Sendable, Equatable {
        case official = "Official"
        case officialForecastOnly = "Official forecast only"
        case minimal = "Unavailable"
    }

    public var location: MarineLocation
    public var generatedAt: Date
    public var daily: [DailyMarineSummary]
    public var warnings: [MarineWarningItem]
    public var dataQuality: DataQuality
    public var degradedReason: String?

    public init(
        location: MarineLocation,
        generatedAt: Date,
        daily: [DailyMarineSummary],
        warnings: [MarineWarningItem],
        dataQuality: DataQuality,
        degradedReason: String?
    ) {
        self.location = location
        self.generatedAt = generatedAt
        self.daily = daily
        self.warnings = warnings
        self.dataQuality = dataQuality
        self.degradedReason = degradedReason
    }
}
