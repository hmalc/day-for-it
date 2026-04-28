import Foundation

public enum BOMConfig {
    /// BOM often returns 403 without a browser-like User-Agent.
    public static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    public static func observationURL(productId: String, stationWmo: Int) -> URL {
        URL(string: "https://www.bom.gov.au/fwo/\(productId)/\(productId).\(stationWmo).json")!
    }

    public static func coastalForecastURL(productId: String) -> URL {
        URL(string: "https://www.bom.gov.au/fwo/\(productId).xml")!
    }
}
