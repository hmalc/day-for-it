import Foundation

public struct BOMHTTPClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = BOMHTTPClient.makeDefaultSession()) {
        self.session = session
    }

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(BOMConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/xml, */*", forHTTPHeaderField: "Accept")
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200 ... 399).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            } catch {
                lastError = error
                if !Self.shouldRetry(error) || attempt == 2 {
                    break
                }
                try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 400_000_000))
            }
        }
        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }

    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 45
        return URLSession(configuration: config)
    }

    private static func shouldRetry(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .resourceUnavailable:
            return true
        default:
            return false
        }
    }
}
