import Foundation

/// Persists daily token/cost aggregates to `~/.claude/runclaude-stats.json`.
/// Merges live data from `BurnRateEngine` (which only tails recent JSONL) with
/// previously saved history so restarts don't lose earlier-in-day data.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var history: [DailyStats] = []

    private let storeURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude")
        .appendingPathComponent("runclaude-stats.json")

    init() { load() }

    /// Merges live daily buckets from the engine into history.
    /// Uses max() to handle restarts: if engine only tailed recent events,
    /// earlier saves for the same day already have a higher count.
    func merge(liveDays: [DailyStats]) {
        var changed = false
        for live in liveDays {
            if let idx = history.firstIndex(where: { $0.date == live.date }) {
                let newTokens  = max(history[idx].tokens,       live.tokens)
                let newCost    = max(history[idx].costUSD,      live.costUSD)
                let newSess    = max(history[idx].sessionCount, live.sessionCount)
                if newTokens != history[idx].tokens || newCost != history[idx].costUSD {
                    history[idx] = DailyStats(date: live.date, tokens: newTokens,
                                              costUSD: newCost, sessionCount: newSess)
                    changed = true
                }
            } else if live.tokens > 0 {
                history.append(live)
                changed = true
            }
        }
        if changed { history.sort { $0.date < $1.date } }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: - Queries

    var todayStats: DailyStats? {
        history.last(where: { $0.date == DailyStats.dateKey() })
    }

    /// Returns data points for the last `days` calendar days, zero-filling gaps.
    func chartData(days: Int) -> [DailyStats] {
        let cal = Calendar.current
        return (0..<days).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let dk = DailyStats.dateKey(for: date)
            return history.first(where: { $0.date == dk })
                ?? DailyStats(date: dk, tokens: 0, costUSD: 0.0, sessionCount: 0)
        }
    }

    // MARK: - Private

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([DailyStats].self, from: data) else { return }
        history = decoded
    }
}
