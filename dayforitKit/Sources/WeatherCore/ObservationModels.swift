import Foundation

public struct FWOObservationResponse: Decodable, Sendable {
    public let observations: FWOObservations

    public struct FWOObservations: Decodable, Sendable {
        public let header: [FWOHeader]?
        public let data: [FWODatum]?
    }

    public struct FWOHeader: Decodable, Sendable {
        public let name: String?
        public let state: String?
        public let refresh_message: String?
    }

    public struct FWODatum: Decodable, Sendable {
        public let local_date_time_full: String?
        public let wind_spd_kmh: Int?
        public let gust_kmh: Int?
        public let air_temp: Double?
        public let rel_hum: Int?
        public let vis_km: String?
        public let rain_trace: String?
    }
}
