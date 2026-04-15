import Foundation

/// Heuristic extraction of marine quantities from BOM coastal text.
public enum MarineTextMetrics: Sendable {
    /// Returns maximum wind speed in km/h from phrases like "10 to 15 knots" or "up to 20 knots".
    public static func maxWindKmh(from text: String) -> Double? {
        let lower = text.lowercased()
        let knotPattern = try? NSRegularExpression(
            pattern: #"(\d+)\s*(?:to|-)\s*(\d+)\s*knots"#,
            options: []
        )
        let upToPattern = try? NSRegularExpression(
            pattern: #"up to\s*(\d+)\s*knots"#,
            options: []
        )
        let singlePattern = try? NSRegularExpression(
            pattern: #"(\d+)\s*knots"#,
            options: []
        )
        let ns = lower as NSString
        var maxKnots: Double = 0

        if let knotPattern {
            let range = NSRange(location: 0, length: ns.length)
            knotPattern.enumerateMatches(in: lower, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 3 else { return }
                let a = ns.substring(with: match.range(at: 1))
                let b = ns.substring(with: match.range(at: 2))
                if let x = Double(a), let y = Double(b) {
                    maxKnots = max(maxKnots, x, y)
                }
            }
        }
        if let upToPattern {
            let range = NSRange(location: 0, length: ns.length)
            upToPattern.enumerateMatches(in: lower, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 2 else { return }
                let a = ns.substring(with: match.range(at: 1))
                if let x = Double(a) {
                    maxKnots = max(maxKnots, x)
                }
            }
        }
        if maxKnots < 1, let singlePattern {
            let range = NSRange(location: 0, length: ns.length)
            singlePattern.enumerateMatches(in: lower, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 2 else { return }
                let a = ns.substring(with: match.range(at: 1))
                if let x = Double(a) {
                    maxKnots = max(maxKnots, x)
                }
            }
        }
        guard maxKnots > 0 else { return nil }
        return maxKnots * 1.852
    }

    /// Largest metre value mentioned (seas or swell lines).
    public static func maxMetres(from text: String) -> Double? {
        let pattern = try? NSRegularExpression(
            pattern: #"(\d+(?:\.\d+)?)\s*(?:to|-)\s*(\d+(?:\.\d+)?)\s*met"#,
            options: []
        )
        let single = try? NSRegularExpression(
            pattern: #"(\d+(?:\.\d+)?)\s*met"#,
            options: []
        )
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var maxM = 0.0
        pattern?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            if let x = Double(ns.substring(with: match.range(at: 1))),
               let y = Double(ns.substring(with: match.range(at: 2))) {
                maxM = max(maxM, x, y)
            }
        }
        single?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2 else { return }
            if let x = Double(ns.substring(with: match.range(at: 1))) {
                maxM = max(maxM, x)
            }
        }
        return maxM > 0 ? maxM : nil
    }

    /// Rough swell period (seconds) if text mentions "long period" etc.
    public static func swellPeriodHint(from text: String) -> Double? {
        let lower = text.lowercased()
        if lower.contains("long period") { return 12 }
        if lower.contains("short period") { return 6 }
        return nil
    }
}
