import Foundation
import PleasantnessEngine

public struct MarineWarningItem: Sendable, Equatable {
    public var title: String
    public var link: String

    public init(title: String, link: String) {
        self.title = title
        self.link = link
    }
}

/// BOM publishes marine warnings as RSS 2.0 XML.
public enum MarineWarningsParser: Sendable {
    public static func parse(data: Data) throws -> [MarineWarningItem] {
        let delegate = MarineWarningsRSSDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return delegate.items
    }

    public static func mapSeverity(title: String) -> ScoringInput.WarningSeverity {
        let lower = title.lowercased()
        if lower.contains("storm force") || lower.contains("hurricane") {
            return .storm
        }
        if lower.contains("gale") {
            return .gale
        }
        if lower.contains("strong wind") || lower.contains("hazardous surf") || lower.contains("severe") {
            return .strong
        }
        return .advisory
    }
}

private final class MarineWarningsRSSDelegate: NSObject, XMLParserDelegate {
    private(set) var items: [MarineWarningItem] = []
    private var inItem = false
    private var currentElement = ""
    private var textBuffer = ""
    private var currentTitle: String?
    private var currentLink: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes _: [String: String] = [:]
    ) {
        currentElement = elementName
        textBuffer = ""
        if elementName == "item" {
            inItem = true
            currentTitle = nil
            currentLink = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { textBuffer = "" }
        guard inItem else { return }

        if elementName == "title" {
            currentTitle = trimmed
        } else if elementName == "link" {
            currentLink = trimmed
        } else if elementName == "item" {
            if let title = currentTitle, let link = currentLink, !title.isEmpty, !link.isEmpty, !Self.isSummaryOnly(title) {
                items.append(MarineWarningItem(title: title, link: link))
            }
            inItem = false
        }
    }

    private static func isSummaryOnly(_ title: String) -> Bool {
        let lower = title.lowercased()
        return lower.contains("warning summary")
    }
}
