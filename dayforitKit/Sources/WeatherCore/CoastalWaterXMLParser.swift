import Foundation

/// Parses BOM coastal waters `product` XML (schema v1.7 style).
public enum CoastalWaterXMLParser: Sendable {
    public static func parse(data: Data) throws -> CoastalForecastDocument {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return delegate.buildDocument()
    }

    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoParserNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    fileprivate static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return isoParser.date(from: s) ?? isoParserNoFrac.date(from: s)
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    private var inAmoc = false
    private var inForecast = false
    private var currentArea: CoastalAreaBuilder?
    private var currentPeriod: CoastalPeriodBuilder?
    private var currentTextType: String?
    private var currentElement = ""
    private var textBuffer = ""

    private(set) var productId = ""
    private(set) var issueTimeUTC: Date?
    private(set) var areas: [CoastalArea] = []

    func buildDocument() -> CoastalForecastDocument {
        CoastalForecastDocument(productId: productId, issueTimeUTC: issueTimeUTC, areas: areas)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        textBuffer = ""

        switch elementName {
        case "amoc":
            inAmoc = true
        case "forecast":
            inForecast = true
        case "area" where inForecast:
            currentArea = CoastalAreaBuilder(
                aac: attributeDict["aac"] ?? "",
                description: attributeDict["description"] ?? "",
                areaType: attributeDict["type"] ?? ""
            )
        case "forecast-period" where currentArea != nil:
            currentPeriod = CoastalPeriodBuilder(
                index: attributeDict["index"].flatMap(Int.init),
                startUTC: CoastalWaterXMLParser.parseDate(attributeDict["start-time-utc"]),
                endUTC: CoastalWaterXMLParser.parseDate(attributeDict["end-time-utc"])
            )
        case "text":
            currentTextType = attributeDict["type"]
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            textBuffer = ""
            currentElement = ""
        }

        if inAmoc {
            if elementName == "identifier" {
                productId = trimmed
            } else if elementName == "issue-time-utc" {
                issueTimeUTC = CoastalWaterXMLParser.parseDate(trimmed)
            } else if elementName == "amoc" {
                inAmoc = false
            }
        }

        if elementName == "text", let type = currentTextType {
            currentPeriod?.setText(type: type, value: trimmed)
            currentTextType = nil
        }

        if elementName == "forecast-period", let period = currentPeriod?.build() {
            currentArea?.periods.append(period)
            currentPeriod = nil
        }

        if elementName == "area", let area = currentArea?.build(), !area.aac.isEmpty {
            areas.append(area)
            currentArea = nil
        }

        if elementName == "forecast" {
            inForecast = false
        }
    }
}

private struct CoastalAreaBuilder {
    var aac: String
    var description: String
    var areaType: String
    var periods: [CoastalPeriod] = []

    func build() -> CoastalArea {
        CoastalArea(aac: aac, description: description, areaType: areaType, periods: periods)
    }
}

private struct CoastalPeriodBuilder {
    var index: Int?
    var startUTC: Date?
    var endUTC: Date?
    var forecastWinds: String?
    var forecastSeas: String?
    var forecastSwell1: String?
    var forecastSwell2: String?
    var forecastWeather: String?
    var forecastCaution: String?
    var synopticSituation: String?
    var preamble: String?

    mutating func setText(type: String, value: String) {
        guard !value.isEmpty else { return }
        switch type {
        case "forecast_winds": forecastWinds = value
        case "forecast_seas": forecastSeas = value
        case "forecast_swell1": forecastSwell1 = value
        case "forecast_swell2": forecastSwell2 = value
        case "forecast_weather": forecastWeather = value
        case "forecast_caution": forecastCaution = value
        case "synoptic_situation": synopticSituation = value
        case "preamble": preamble = value
        default: break
        }
    }

    func build() -> CoastalPeriod {
        CoastalPeriod(
            index: index,
            startUTC: startUTC,
            endUTC: endUTC,
            forecastWinds: forecastWinds,
            forecastSeas: forecastSeas,
            forecastSwell1: forecastSwell1,
            forecastSwell2: forecastSwell2,
            forecastWeather: forecastWeather,
            forecastCaution: forecastCaution,
            synopticSituation: synopticSituation,
            preamble: preamble
        )
    }
}
