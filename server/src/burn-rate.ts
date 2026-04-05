import type { TokenEvent, SessionState, ModelBreakdown } from "./types";

const WINDOW_MS = 60_000; // 60-second sliding window

// Pricing per 1M tokens (USD) — keep in sync with Anthropic pricing.
// Resolved by substring match on the model identifier.
interface ModelPricing {
  input: number;
  output: number;
  cacheWrite: number;
  cacheRead: number;
}

const PRICING: Array<{ match: RegExp; price: ModelPricing }> = [
  { match: /opus/i,   price: { input: 15,   output: 75, cacheWrite: 18.75, cacheRead: 1.5  } },
  { match: /sonnet/i, price: { input: 3,    output: 15, cacheWrite: 3.75,  cacheRead: 0.3  } },
  { match: /haiku/i,  price: { input: 0.8,  output: 4,  cacheWrite: 1.0,   cacheRead: 0.08 } },
];

const DEFAULT_PRICING: ModelPricing = { input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3 };

function priceFor(model: string): ModelPricing {
  for (const p of PRICING) {
    if (p.match.test(model)) return p.price;
  }
  return DEFAULT_PRICING;
}

function costForSession(s: SessionState): number {
  const p = priceFor(s.model);
  return (
    (s.totalInputTokens          * p.input      +
     s.totalOutputTokens         * p.output     +
     s.totalCacheCreationTokens  * p.cacheWrite +
     s.totalCacheReadTokens      * p.cacheRead) / 1_000_000
  );
}

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
    return Array.from(this.sessions.values())
      .filter((s) => s.lastSeen > fiveMinAgo)
      .sort((a, b) => b.lastSeen.getTime() - a.lastSeen.getTime());
  }

  getAllSessions(): SessionState[] {
    return Array.from(this.sessions.values());
  }

  getTotalSessions(): number {
    return this.sessions.size;
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
      cost += costForSession(s);
    }
    return cost;
  }

  /**
   * Aggregates tokens and cost by model across all sessions, sorted by cost descending.
   * Models are grouped by matching family (opus/sonnet/haiku) — exact model string wins.
   */
  getModelBreakdown(): ModelBreakdown[] {
    const byModel = new Map<string, ModelBreakdown>();

    for (const s of this.sessions.values()) {
      const key = s.model || "unknown";
      let entry = byModel.get(key);
      if (!entry) {
        entry = {
          model: key,
          tokens: 0,
          costUsd: 0,
          sessionCount: 0,
          inputTokens: 0,
          outputTokens: 0,
          cacheCreationTokens: 0,
          cacheReadTokens: 0,
        };
        byModel.set(key, entry);
      }
      entry.inputTokens          += s.totalInputTokens;
      entry.outputTokens         += s.totalOutputTokens;
      entry.cacheCreationTokens  += s.totalCacheCreationTokens;
      entry.cacheReadTokens      += s.totalCacheReadTokens;
      entry.tokens +=
        s.totalInputTokens +
        s.totalOutputTokens +
        s.totalCacheCreationTokens +
        s.totalCacheReadTokens;
      entry.costUsd += costForSession(s);
      entry.sessionCount += 1;
    }

    return Array.from(byModel.values()).sort((a, b) => b.costUsd - a.costUsd);
  }
}
