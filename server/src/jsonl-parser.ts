import type { JSONLEntry, TokenEvent } from "./types";

export function parseJSONLLine(line: string): JSONLEntry | null {
  try {
    return JSON.parse(line) as JSONLEntry;
  } catch {
    return null;
  }
}

export function extractTokenEvent(entry: JSONLEntry): TokenEvent | null {
  if (entry.type !== "assistant") return null;

  const usage = entry.message?.usage;
  if (!usage) return null;

  const inputTokens = usage.input_tokens ?? 0;
  const outputTokens = usage.output_tokens ?? 0;
  const cacheCreation = usage.cache_creation_input_tokens ?? 0;
  const cacheRead = usage.cache_read_input_tokens ?? 0;
  const totalTokens = inputTokens + outputTokens + cacheCreation + cacheRead;

  if (totalTokens === 0) return null;

  return {
    timestamp: new Date(entry.timestamp),
    tokens: totalTokens,
    usage: {
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      cache_creation_input_tokens: cacheCreation,
      cache_read_input_tokens: cacheRead,
    },
    model: entry.message?.model ?? "unknown",
    sessionId: entry.sessionId,
  };
}
