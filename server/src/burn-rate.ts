import type { TokenEvent, SessionState } from "./types";

const WINDOW_MS = 60_000; // 60-second sliding window

export class BurnRateCalculator {
  private events: TokenEvent[] = [];
  private sessions = new Map<string, SessionState>();

  addEvent(event: TokenEvent) {
    this.events.push(event);
    this.updateSession(event);
    this.pruneOldEvents();
  }

  private updateSession(event: TokenEvent) {
    const existing = this.sessions.get(event.sessionId);

    if (existing) {
      existing.totalInputTokens += event.usage.input_tokens;
      existing.totalOutputTokens += event.usage.output_tokens;
      existing.totalCacheCreationTokens += event.usage.cache_creation_input_tokens;
      existing.totalCacheReadTokens += event.usage.cache_read_input_tokens;
      existing.lastSeen = event.timestamp;
      existing.model = event.model;
    } else {
      this.sessions.set(event.sessionId, {
        sessionId: event.sessionId,
        slug: "",
        project: "",
        model: event.model,
        totalInputTokens: event.usage.input_tokens,
        totalOutputTokens: event.usage.output_tokens,
        totalCacheCreationTokens: event.usage.cache_creation_input_tokens,
        totalCacheReadTokens: event.usage.cache_read_input_tokens,
        firstSeen: event.timestamp,
        lastSeen: event.timestamp,
      });
    }
  }

  updateSessionMeta(sessionId: string, slug: string, project: string) {
    const session = this.sessions.get(sessionId);
    if (session) {
      if (slug) session.slug = slug;
      if (project) session.project = project;
    }
  }

  private pruneOldEvents() {
    const cutoff = Date.now() - WINDOW_MS;
    this.events = this.events.filter((e) => e.timestamp.getTime() > cutoff);
  }

  getTokensPerSecond(): number {
    this.pruneOldEvents();

    if (this.events.length === 0) return 0;

    const totalTokens = this.events.reduce((sum, e) => sum + e.tokens, 0);
    const oldest = this.events[0].timestamp.getTime();
    const newest = this.events[this.events.length - 1].timestamp.getTime();
    const durationSec = Math.max((newest - oldest) / 1000, 1);

    return totalTokens / durationSec;
  }

  getActiveSessions(): SessionState[] {
    const fiveMinAgo = new Date(Date.now() - 5 * 60_000);
    return Array.from(this.sessions.values()).filter(
      (s) => s.lastSeen > fiveMinAgo
    );
  }

  getAllSessions(): SessionState[] {
    return Array.from(this.sessions.values());
  }

  getTotalTokens(): number {
    let total = 0;
    for (const s of this.sessions.values()) {
      total +=
        s.totalInputTokens +
        s.totalOutputTokens +
        s.totalCacheCreationTokens +
        s.totalCacheReadTokens;
    }
    return total;
  }

  getEstimatedCost(): number {
    let cost = 0;
    for (const s of this.sessions.values()) {
      const isOpus = s.model?.includes("opus");
      const inputRate = isOpus ? 15 / 1_000_000 : 3 / 1_000_000;
      const outputRate = isOpus ? 75 / 1_000_000 : 15 / 1_000_000;
      const cacheWriteRate = isOpus ? 18.75 / 1_000_000 : 3.75 / 1_000_000;
      const cacheReadRate = isOpus ? 1.5 / 1_000_000 : 0.3 / 1_000_000;

      cost += s.totalInputTokens * inputRate;
      cost += s.totalOutputTokens * outputRate;
      cost += s.totalCacheCreationTokens * cacheWriteRate;
      cost += s.totalCacheReadTokens * cacheReadRate;
    }
    return cost;
  }
}
