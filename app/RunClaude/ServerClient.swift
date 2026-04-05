import Foundation

struct StatusResponse: Codable {
    let serverStartedAt: String
    let tokensPerSecond: Double
    let windowSeconds: Int
    let totalTokens: Int
    let estimatedCostUsd: Double
    let totalSessions: Int
    let activeSessions: [SessionInfo]
    let modelBreakdown: [ModelBreakdown]

    var serverStartedAtDate: Date? {
        ISO8601DateFormatter.withFractional.date(from: serverStartedAt)
            ?? ISO8601DateFormatter().date(from: serverStartedAt)
    }
}

struct ModelBreakdown: Codable, Identifiable {
    let model: String
    let tokens: Int
    let costUsd: Double
    let sessionCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var id: String { model }
}

struct SessionInfo: Codable, Identifiable {
    let sessionId: String
    let slug: String
    let project: String
    let model: String
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheCreationTokens: Int
    let totalCacheReadTokens: Int
    let firstSeen: String
    let lastSeen: String

    var id: String { sessionId }

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

@MainActor
class ServerClient: ObservableObject {
    @Published var status: StatusResponse?
    @Published var isConnected = false

    private let baseURL = "http://localhost:17888"

    func fetchStatus() async -> StatusResponse? {
        guard let url = URL(string: "\(baseURL)/status") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
            self.status = decoded
            self.isConnected = true
            return decoded
        } catch {
            self.isConnected = false
            return nil
        }
    }
}
