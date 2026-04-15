import Foundation

public struct SubScore: Sendable, Equatable {
    /// 0 = worst, 100 = best for this dimension.
    public var value: Double
    public var label: String
    public var detail: String

    public init(value: Double, label: String, detail: String) {
        self.value = value
        self.label = label
        self.detail = detail
    }
}

public struct PleasantnessResult: Sendable, Equatable {
    /// 0...100 overall pleasantness after guardrails.
    public var index: Double
    public var subScores: [SubScore]
    /// Largest contributors to a lower score (plain language).
    public var topDrivers: [String]
    public var isWarningLimited: Bool
    public var warningSummary: String?

    public init(
        index: Double,
        subScores: [SubScore],
        topDrivers: [String],
        isWarningLimited: Bool,
        warningSummary: String?
    ) {
        self.index = index
        self.subScores = subScores
        self.topDrivers = topDrivers
        self.isWarningLimited = isWarningLimited
        self.warningSummary = warningSummary
    }
}
