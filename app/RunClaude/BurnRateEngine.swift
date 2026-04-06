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

    // Tool tracking
    var toolCounts: [String: Int] = [:]
    var errorCount: Int = 0

    // Effort signals
    var userTurnCount: Int = 0
    var assistantTurnCount: Int = 0
    var idleTime: TimeInterval = 0.0

    // Action signals
    var mcpCallCount: Int = 0
    var agentSpawnCount: Int = 0
    var commandUsage: [String: Int] = [:]

    // Output signals
    var commitCount: Int = 0
    var prCount: Int = 0

    // Cost
    var estimatedCostUSD: Double = 0.0

    var id: String { sessionId }

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }
    var duration: TimeInterval   { lastSeen.timeIntervalSince(firstSeen) }
    var activeTime: TimeInterval { max(0, duration - idleTime) }
    var totalToolCalls: Int      { toolCounts.values.reduce(0, +) }
    var totalTurns: Int          { userTurnCount + assistantTurnCount }
    var humanTurnsRatio: Double  { totalTurns == 0 ? 0 : Double(userTurnCount) / Double(totalTurns) }

    var topTools: [ToolStat] {
        toolCounts.sorted { $0.value > $1.value }.prefix(5).map { ToolStat(name: $0.key, count: $0.value) }
    }
    var topCommands: [ToolStat] {
        commandUsage.sorted { $0.value > $1.value }.prefix(5).map { ToolStat(name: $0.key, count: $0.value) }
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

struct ToolStat: Identifiable {
    let name: String
    var count: Int
    var id: String { name }
}

struct StatusSnapshot {
    let serverStartedAt: Date
    let tokensPerSecond: Double
    let windowSeconds: Int
    let totalTokens: Int
    let totalSessions: Int
    let activeSessions: [SessionInfo]
    let modelBreakdown: [ModelBreakdown]
    // Analytics
    let totalCostUSD: Double
    let allSessions: [SessionInfo]
    let topTools: [ToolStat]
    let topCommands: [ToolStat]
    let totalCommits: Int
    let totalPRs: Int
    let totalMCPCalls: Int
    let totalAgentSpawns: Int
}

// MARK: - Engine

@MainActor
final class BurnRateEngine: ObservableObject {
    static let windowSeconds = 60

    @Published private(set) var status: StatusSnapshot?

    let startedAt = Date()
    private var events: [TokenEvent] = []
    private var sessions: [String: SessionInfo] = [:]

    // MARK: - Public API

    func addEvent(_ event: TokenEvent) {
        events.append(event)
        updateSession(with: event)
        pruneEvents()
    }

    /// Called for every message (user or assistant) to count turns and track idle gaps.
    func recordTurn(sessionId: String, isUser: Bool, idleGap: TimeInterval) {
        guard var session = sessions[sessionId] else { return }
        // Gap between 2 min and 2 hours = intentional pause (idle), not session boundary
        if idleGap > 120 && idleGap < 7200 { session.idleTime += idleGap }
        if isUser { session.userTurnCount += 1 } else { session.assistantTurnCount += 1 }
        sessions[sessionId] = session
    }

    /// Records a tool_use block. Classifies MCP, Agent, git commit, and gh pr automatically.
    func addToolCall(sessionId: String, toolName: String, bashCommand: String? = nil) {
        guard var session = sessions[sessionId] else { return }
        session.toolCounts[toolName, default: 0] += 1

        if toolName.contains("__") {
            session.mcpCallCount += 1
        } else if toolName == "Agent" {
            session.agentSpawnCount += 1
        }

        if let cmd = bashCommand {
            if cmd.contains("git commit") { session.commitCount += 1 }
            if cmd.contains("gh pr create") { session.prCount += 1 }
        }

        sessions[sessionId] = session
    }

    func addToolError(sessionId: String) {
        guard var session = sessions[sessionId] else { return }
        session.errorCount += 1
        sessions[sessionId] = session
    }

    func addCommand(sessionId: String, command: String) {
        guard var session = sessions[sessionId] else { return }
        session.commandUsage[command, default: 0] += 1
        sessions[sessionId] = session
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
        let all = allSessions()
        status = StatusSnapshot(
            serverStartedAt: startedAt,
            tokensPerSecond: tokensPerSecond(),
            windowSeconds: Self.windowSeconds,
            totalTokens: totalTokens(),
            totalSessions: sessions.count,
            activeSessions: activeSessions(),
            modelBreakdown: modelBreakdown(),
            totalCostUSD: all.reduce(0) { $0 + $1.estimatedCostUSD },
            allSessions: all,
            topTools: aggregatedTopStats(keyPath: \.toolCounts),
            topCommands: aggregatedTopStats(keyPath: \.commandUsage),
            totalCommits: all.reduce(0) { $0 + $1.commitCount },
            totalPRs: all.reduce(0) { $0 + $1.prCount },
            totalMCPCalls: all.reduce(0) { $0 + $1.mcpCallCount },
            totalAgentSpawns: all.reduce(0) { $0 + $1.agentSpawnCount }
        )
    }

    // MARK: - Cost estimation (Anthropic pricing, per million tokens)
    // Rates: input / output / cache-write / cache-read
    // Opus: $15 / $75 / $18.75 / $1.50
    // Sonnet (default): $3 / $15 / $3.75 / $0.30
    // Haiku: $0.80 / $4 / $1.00 / $0.08

    static func estimateCostUSD(model: String, usage: TokenUsage) -> Double {
        let lower = model.lowercased()
        var inputRate = 3.0, outputRate = 15.0, cacheWriteRate = 3.75, cacheReadRate = 0.30
        if lower.contains("opus") {
            (inputRate, outputRate, cacheWriteRate, cacheReadRate) = (15.0, 75.0, 18.75, 1.50)
        } else if lower.contains("haiku") {
            (inputRate, outputRate, cacheWriteRate, cacheReadRate) = (0.80, 4.0, 1.00, 0.08)
        }
        return (Double(usage.inputTokens)         * inputRate      +
                Double(usage.outputTokens)        * outputRate     +
                Double(usage.cacheCreationTokens) * cacheWriteRate +
                Double(usage.cacheReadTokens)     * cacheReadRate) / 1_000_000
    }

    // MARK: - Private

    private func updateSession(with event: TokenEvent) {
        let cost = Self.estimateCostUSD(model: event.model, usage: event.usage)
        if var existing = sessions[event.sessionId] {
            existing.totalInputTokens         += event.usage.inputTokens
            existing.totalOutputTokens        += event.usage.outputTokens
            existing.totalCacheCreationTokens += event.usage.cacheCreationTokens
            existing.totalCacheReadTokens     += event.usage.cacheReadTokens
            existing.estimatedCostUSD         += cost
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
                lastSeen: event.timestamp,
                estimatedCostUSD: cost
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

    private func allSessions() -> [SessionInfo] {
        sessions.values.sorted { $0.lastSeen > $1.lastSeen }
    }

    private func aggregatedTopStats(keyPath: KeyPath<SessionInfo, [String: Int]>) -> [ToolStat] {
        var totals: [String: Int] = [:]
        for session in sessions.values {
            for (name, count) in session[keyPath: keyPath] {
                totals[name, default: 0] += count
            }
        }
        return totals.sorted { $0.value > $1.value }
            .prefix(10)
            .map { ToolStat(name: $0.key, count: $0.value) }
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
