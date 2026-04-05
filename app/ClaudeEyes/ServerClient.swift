import Foundation

struct StatusResponse: Codable {
    let tokensPerSecond: Double
    let activeSessions: [SessionInfo]
    let totalTokens: Int
    let estimatedCostUsd: Double
    let windowSeconds: Int
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
