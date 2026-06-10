import Foundation
import CoreLocation
import WeatherCore

/// Resolves the active location and its BOM feed bindings.
/// Pure and stateless so both AppModel and the background alert task can use it.
enum LocationFeedResolver {
    static let defaultLocation = MarineLocation(
        name: "Cowley Beach",
        latitude: -17.679,
        longitude: 146.112,
        timeZoneID: "Australia/Brisbane"
    )

    static func effectiveLocation(override: StoredLocation?) -> MarineLocation {
        override?.marineLocation ?? defaultLocation
    }

    static func feedConfig(for location: MarineLocation) -> MarineFeedConfig {
        let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        if isQueenslandCoordinate(coord) {
            return queenslandFeed(for: coord)
        }

        if
            let nearest = LocationPreset.nearestForecastOnly(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            let feed = nearest.feed
        {
            return feed
        }

        return CoastalPreset.brisbane.feed
    }

    static func isQueenslandCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        let insideBroadQueenslandBounds = (-29.5 ... -9.0).contains(coord.latitude) && (137.5 ... 154.5).contains(coord.longitude)
        let southOfCoastalBorder = coord.latitude < -28.25 && coord.longitude > 151.0
        return insideBroadQueenslandBounds && !southOfCoastalBorder
    }

    static func supportsManualLocation(latitude: Double, longitude: Double) -> Bool {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return isQueenslandCoordinate(coord) || LocationPreset.nearestForecastOnly(
            latitude: latitude,
            longitude: longitude
        ) != nil
    }

    static func timeZoneID(latitude: Double, longitude: Double) -> String {
        if isQueenslandCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
            return "Australia/Brisbane"
        }
        return LocationPreset.nearestForecastOnly(latitude: latitude, longitude: longitude)?.timeZoneID ?? "Australia/Sydney"
    }

    private static func queenslandFeed(for coord: CLLocationCoordinate2D) -> MarineFeedConfig {
        var feed = CoastalPreset.brisbane.feed
        feed.preferredCoastalAAC = QLDMarineZone.nearestAAC(to: coord)
        if let observationStation = QLDObservationStation.nearest(to: coord) {
            feed.observationProductID = observationStation.productID
            feed.observationStationWMO = observationStation.wmo
        }
        return feed
    }
}

enum CoastalPreset: CaseIterable {
    case sydney
    case melbourne
    case brisbane

    var location: MarineLocation {
        switch self {
        case .sydney:
            return MarineLocation(name: "Sydney Coast", latitude: -33.86, longitude: 151.21, timeZoneID: "Australia/Sydney")
        case .melbourne:
            return MarineLocation(name: "Port Phillip Coast", latitude: -37.81, longitude: 144.96, timeZoneID: "Australia/Sydney")
        case .brisbane:
            return MarineLocation(name: "Moreton Bay Coast", latitude: -27.47, longitude: 153.03, timeZoneID: "Australia/Sydney")
        }
    }

    var feed: MarineFeedConfig {
        switch self {
        case .sydney:
            return MarineFeedConfig(
                coastalProductID: "IDN11001",
                observationProductID: "IDN60801",
                observationStationWMO: 95766,
                marineWarningRSSPath: "/fwo/IDZ00068.warnings_marine_nsw.xml",
                preferredCoastalAAC: "NSW_MW004"
            )
        case .melbourne:
            return MarineFeedConfig(
                coastalProductID: "IDV10200",
                observationProductID: "IDV60801",
                observationStationWMO: 94892,
                marineWarningRSSPath: "/fwo/IDZ00073.warnings_marine_vic.xml",
                preferredCoastalAAC: "VIC_MW002"
            )
        case .brisbane:
            return MarineFeedConfig(
                coastalProductID: "IDQ11290",
                observationProductID: "IDQ60801",
                observationStationWMO: 94576,
                marineWarningRSSPath: "/fwo/IDZ00070.warnings_marine_qld.xml",
                preferredCoastalAAC: nil
            )
        }
    }
}

private struct QLDMarineZone {
    let aac: String
    let latitude: Double
    let longitude: Double

    static let all: [QLDMarineZone] = [
        .init(aac: "QLD_MW001", latitude: -15.5, longitude: 141.6),
        .init(aac: "QLD_MW002", latitude: -12.4, longitude: 142.8),
        .init(aac: "QLD_MW003", latitude: -10.7, longitude: 142.2),
        .init(aac: "QLD_MW004", latitude: -13.2, longitude: 143.8),
        .init(aac: "QLD_MW005", latitude: -14.8, longitude: 145.0),
        .init(aac: "QLD_MW006", latitude: -16.5, longitude: 145.8),
        .init(aac: "QLD_MW007", latitude: -18.7, longitude: 146.6),
        .init(aac: "QLD_MW008", latitude: -20.7, longitude: 149.2),
        .init(aac: "QLD_MW009", latitude: -23.6, longitude: 151.2),
        .init(aac: "QLD_MW010", latitude: -25.2, longitude: 152.9),
        .init(aac: "QLD_MW011", latitude: -25.8, longitude: 153.2),
        .init(aac: "QLD_MW012", latitude: -26.6, longitude: 153.1),
        .init(aac: "QLD_MW013", latitude: -27.3, longitude: 153.2),
        .init(aac: "QLD_MW014", latitude: -28.1, longitude: 153.5),
        .init(aac: "QLD_MW015", latitude: -19.5, longitude: 149.8),
    ]

    static func nearestAAC(to coord: CLLocationCoordinate2D) -> String {
        all.min(by: { lhs, rhs in
            let d1 = hypot(lhs.latitude - coord.latitude, lhs.longitude - coord.longitude)
            let d2 = hypot(rhs.latitude - coord.latitude, rhs.longitude - coord.longitude)
            return d1 < d2
        })?.aac ?? "QLD_MW013"
    }
}

private struct QLDObservationStation {
    let productID: String
    let wmo: Int
    let latitude: Double
    let longitude: Double

    static let all: [QLDObservationStation] = [
        .init(productID: "IDQ60801", wmo: 94280, latitude: -17.56, longitude: 146.01), // Innisfail Aerodrome
        .init(productID: "IDQ60801", wmo: 94287, latitude: -16.87, longitude: 145.75), // Cairns Aero
        .init(productID: "IDQ60801", wmo: 94285, latitude: -16.38, longitude: 145.56), // Low Isles Lighthouse
        .init(productID: "IDQ60801", wmo: 94294, latitude: -19.25, longitude: 146.77), // Townsville Aero
        .init(productID: "IDQ60801", wmo: 94368, latitude: -20.37, longitude: 148.95), // Hamilton Island Airport
        .init(productID: "IDQ60801", wmo: 94367, latitude: -21.12, longitude: 149.22), // Mackay M.O
        .init(productID: "IDQ60801", wmo: 94373, latitude: -23.14, longitude: 150.75), // Yeppoon
        .init(productID: "IDQ60801", wmo: 94380, latitude: -23.86, longitude: 151.26), // Gladstone
        .init(productID: "IDQ60801", wmo: 94387, latitude: -24.91, longitude: 152.32), // Bundaberg Aero
        .init(productID: "IDQ60801", wmo: 95565, latitude: -25.32, longitude: 152.88), // Hervey Bay Airport
        .init(productID: "IDQ60801", wmo: 94569, latitude: -26.60, longitude: 153.09), // Sunshine Coast Airport
        .init(productID: "IDQ60801", wmo: 94576, latitude: -27.48, longitude: 153.04), // Brisbane
        .init(productID: "IDQ60801", wmo: 94580, latitude: -27.94, longitude: 153.43), // Gold Coast Seaway
    ]

    static func nearest(to coord: CLLocationCoordinate2D) -> QLDObservationStation? {
        all.min(by: { lhs, rhs in
            let d1 = hypot(lhs.latitude - coord.latitude, lhs.longitude - coord.longitude)
            let d2 = hypot(rhs.latitude - coord.latitude, rhs.longitude - coord.longitude)
            return d1 < d2
        })
    }
}
