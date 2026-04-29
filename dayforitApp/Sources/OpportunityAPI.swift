import Foundation
import WeatherCore

struct OpportunityActivity: Identifiable, Equatable {
    let id: String
    let label: String
    let systemImage: String

    static let all: [OpportunityActivity] = [
        .init(id: "mowing", label: "Mowing", systemImage: "scissors"),
        .init(id: "gardening", label: "Gardening", systemImage: "leaf"),
        .init(id: "picnic", label: "Picnic", systemImage: "basket"),
        .init(id: "laundry", label: "Laundry", systemImage: "tshirt"),
        .init(id: "running", label: "Run / walk", systemImage: "figure.walk"),
        .init(id: "boating", label: "Boating", systemImage: "sailboat")
    ]

    static func label(for id: String) -> String {
        all.first(where: { $0.id == id })?.label ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct OpportunityRecommendation: Identifiable, Decodable, Equatable {
    struct Window: Decodable, Equatable {
        let start: Date
        let end: Date
    }

    let id: String
    let activity: String
    let title: String
    let description: String
    let window: Window
    let priority: String
    let confidence: String
    let verdict: String
    let finalScore: Double
    let suitabilityScore: Double
    let opportunityScore: Double
    let relevanceScore: Double
    let reasons: [String]
    let riskFlags: [String]
    let invalidationConditions: [String]
    let feedbackPrompt: String
    let scoringVersion: String

    enum CodingKeys: String, CodingKey {
        case id
        case activity
        case title
        case description
        case window
        case priority
        case confidence
        case verdict
        case finalScore = "final_score"
        case suitabilityScore = "suitability_score"
        case opportunityScore = "opportunity_score"
        case relevanceScore = "relevance_score"
        case reasons
        case riskFlags = "risk_flags"
        case invalidationConditions = "invalidation_conditions"
        case feedbackPrompt = "feedback_prompt"
        case scoringVersion = "scoring_version"
    }

    init(
        id: String,
        activity: String,
        title: String,
        description: String,
        window: Window,
        priority: String,
        confidence: String,
        verdict: String,
        finalScore: Double,
        suitabilityScore: Double,
        opportunityScore: Double,
        relevanceScore: Double,
        reasons: [String],
        riskFlags: [String],
        invalidationConditions: [String],
        feedbackPrompt: String,
        scoringVersion: String
    ) {
        self.id = id
        self.activity = activity
        self.title = title
        self.description = description
        self.window = window
        self.priority = priority
        self.confidence = confidence
        self.verdict = verdict
        self.finalScore = finalScore
        self.suitabilityScore = suitabilityScore
        self.opportunityScore = opportunityScore
        self.relevanceScore = relevanceScore
        self.reasons = reasons
        self.riskFlags = riskFlags
        self.invalidationConditions = invalidationConditions
        self.feedbackPrompt = feedbackPrompt
        self.scoringVersion = scoringVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        activity = try container.decode(String.self, forKey: .activity)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        window = try container.decode(Window.self, forKey: .window)
        priority = try container.decode(String.self, forKey: .priority)
        confidence = try container.decode(String.self, forKey: .confidence)
        verdict = try container.decode(String.self, forKey: .verdict)
        finalScore = try container.decode(Double.self, forKey: .finalScore)
        suitabilityScore = try container.decode(Double.self, forKey: .suitabilityScore)
        opportunityScore = try container.decode(Double.self, forKey: .opportunityScore)
        relevanceScore = try container.decode(Double.self, forKey: .relevanceScore)
        reasons = try container.decodeIfPresent([String].self, forKey: .reasons) ?? []
        riskFlags = try container.decodeIfPresent([String].self, forKey: .riskFlags) ?? []
        invalidationConditions = try container.decodeIfPresent([String].self, forKey: .invalidationConditions) ?? []
        feedbackPrompt = try container.decode(String.self, forKey: .feedbackPrompt)
        scoringVersion = try container.decode(String.self, forKey: .scoringVersion)
    }
}

struct OpportunityScanResponse: Decodable, Equatable {
    let fetchedAt: Date
    let forecastSnapshotID: String?
    let recommendations: [OpportunityRecommendation]
    let attribution: String?

    enum CodingKeys: String, CodingKey {
        case fetchedAt = "fetched_at"
        case forecastSnapshotID = "forecast_snapshot_id"
        case recommendations
        case attribution
    }
}

@MainActor
protocol OpportunityClientProtocol {
    func scan(location: MarineLocation, clientID: String, interests: [String]) async throws -> OpportunityScanResponse
    func submitFeedback(recommendationID: String, clientID: String, feedback: OpportunityFeedback) async throws
}

struct OpportunityFeedback: Equatable {
    let didAct: String
    let outcome: String?
    let reason: String?
    let freeText: String?
}

struct OpportunityClient: OpportunityClientProtocol {
    var baseURL = URL(string: "http://dayforit-dev-api-822158680.ap-southeast-2.elb.amazonaws.com")!
    var session: URLSession = .shared

    func scan(location: MarineLocation, clientID: String, interests: [String]) async throws -> OpportunityScanResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/recommendations/scan"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ScanPayload(
            clientID: clientID,
            location: .init(
                lat: location.latitude,
                lon: location.longitude,
                name: location.name,
                timezone: location.timeZoneID
            ),
            timeRange: .init(days: 7),
            interests: interests
        ))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try Self.decoder.decode(OpportunityScanResponse.self, from: data)
    }

    func submitFeedback(recommendationID: String, clientID: String, feedback: OpportunityFeedback) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/v1/recommendations/\(recommendationID)/feedback"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(FeedbackPayload(
            clientID: clientID,
            didAct: feedback.didAct,
            outcome: feedback.outcome,
            reason: feedback.reason,
            freeText: feedback.freeText
        ))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw OpportunityClientError.server(message)
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseISO8601Date(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(raw)")
        }
        return decoder
    }()

    nonisolated private static func parseISO8601Date(_ raw: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: raw) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: raw)
    }
}

enum OpportunityClientError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case let .server(message): return message
        }
    }
}

private struct ScanPayload: Encodable {
    struct Location: Encodable {
        let lat: Double
        let lon: Double
        let name: String
        let timezone: String
    }

    struct TimeRange: Encodable {
        let days: Int
    }

    let clientID: String
    let location: Location
    let timeRange: TimeRange
    let interests: [String]

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case location
        case timeRange = "time_range"
        case interests
    }
}

private struct FeedbackPayload: Encodable {
    let clientID: String
    let didAct: String
    let outcome: String?
    let reason: String?
    let freeText: String?

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case didAct = "did_act"
        case outcome
        case reason
        case freeText = "free_text"
    }
}

struct OpportunityClientIDStore {
    private let defaults: UserDefaults
    private let key = "opportunity_client_id_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadOrCreate() -> String {
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: key)
        return created
    }
}
