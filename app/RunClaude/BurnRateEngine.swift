import Foundation

// MARK: - Models

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
}

struct TokenEvent {
    let timestamp: Date
    let tokens: Int
    let usage: TokenUsage
    let model: String
    let sessionId: String
}

struct SessionInfo: Identifiable {
    let sessionId: String
    var slug: String
    var project: String
    var model: String
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalCacheCreationTokens: Int
    var totalCacheReadTokens: Int
    var firstSeen: Date
    var lastSeen: Date

    var id: String { sessionId }
    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }
}

struct ModelBreakdown: Identifiable {
    let model: String
    var tokens: Int
    var sessionCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int

    var id: String { model }
}

struct StatusSnapshot {
    let serverStartedAt: Date
    let tokensPerSecond: Double
    let windowSeconds: Int
    let totalTokens: Int
    let totalSessions: Int
    let activeSessions: [SessionInfo]
    let modelBreakdown: [ModelBreakdown]
}

// MARK: - Engine

@MainActor
final class BurnRateEngine: ObservableObject {
    static let windowSeconds = 60

    @Published private(set) var status: StatusSnapshot?

    let startedAt = Date()
    private var events: [TokenEvent] = []
    private var sessions: [String: SessionInfo] = [:]

    func addEvent(_ event: TokenEvent) {
        events.append(event)
        updateSession(with: event)
        pruneEvents()
    }

    func updateSessionMeta(sessionId: String, slug: String, project: String) {
        guard var session = sessions[sessionId] else { return }
        if !slug.isEmpty    { session.slug = slug }
        if !project.isEmpty { session.project = project }
        sessions[sessionId] = session
    }

    /// Recomputes the published snapshot. Call after a batch of events.
    func refreshSnapshot() {
        pruneEvents()
        status = StatusSnapshot(
            serverStartedAt: startedAt,
            tokensPerSecond: tokensPerSecond(),
            windowSeconds: Self.windowSeconds,
            totalTokens: totalTokens(),
            totalSessions: sessions.count,
            activeSessions: activeSessions(),
            modelBreakdown: modelBreakdown()
        )
    }

    private func updateSession(with event: TokenEvent) {
        if var existing = sessions[event.sessionId] {
            existing.totalInputTokens         += event.usage.inputTokens
            existing.totalOutputTokens        += event.usage.outputTokens
            existing.totalCacheCreationTokens += event.usage.cacheCreationTokens
            existing.totalCacheReadTokens     += event.usage.cacheReadTokens
            existing.lastSeen = event.timestamp
            existing.model = event.model
            sessions[event.sessionId] = existing
        } else {
            sessions[event.sessionId] = SessionInfo(
                sessionId: event.sessionId,
                slug: "",
                project: "",
                model: event.model,
                totalInputTokens: event.usage.inputTokens,
                totalOutputTokens: event.usage.outputTokens,
                totalCacheCreationTokens: event.usage.cacheCreationTokens,
                totalCacheReadTokens: event.usage.cacheReadTokens,
                firstSeen: event.timestamp,
                lastSeen: event.timestamp
            )
        }
    }

    private func pruneEvents() {
        let cutoff = Date().addingTimeInterval(-Double(Self.windowSeconds))
        events.removeAll { $0.timestamp < cutoff }
    }

    private func tokensPerSecond() -> Double {
        guard let first = events.first, let last = events.last else { return 0 }
        let total = events.reduce(0) { $0 + $1.tokens }
        let duration = max(last.timestamp.timeIntervalSince(first.timestamp), 1)
        return Double(total) / duration
    }

    private func totalTokens() -> Int {
        sessions.values.reduce(0) { acc, s in
            acc + s.totalInputTokens + s.totalOutputTokens +
                  s.totalCacheCreationTokens + s.totalCacheReadTokens
        }
    }

    private func activeSessions() -> [SessionInfo] {
        let cutoff = Date().addingTimeInterval(-5 * 60)
        return sessions.values
            .filter { $0.lastSeen > cutoff }
            .sorted { $0.lastSeen > $1.lastSeen }
    }

    private func modelBreakdown() -> [ModelBreakdown] {
        var byModel: [String: ModelBreakdown] = [:]
        for s in sessions.values {
            let key = s.model.isEmpty ? "unknown" : s.model
            var entry = byModel[key] ?? ModelBreakdown(
                model: key, tokens: 0, sessionCount: 0,
                inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0
            )
            entry.inputTokens         += s.totalInputTokens
            entry.outputTokens        += s.totalOutputTokens
            entry.cacheCreationTokens += s.totalCacheCreationTokens
            entry.cacheReadTokens     += s.totalCacheReadTokens
            entry.tokens +=
                s.totalInputTokens + s.totalOutputTokens +
                s.totalCacheCreationTokens + s.totalCacheReadTokens
            entry.sessionCount += 1
            byModel[key] = entry
        }
        return byModel.values.sorted { $0.tokens > $1.tokens }
    }
}
