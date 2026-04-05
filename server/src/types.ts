export interface TokenUsage {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens: number;
  cache_read_input_tokens: number;
}

export interface TokenEvent {
  timestamp: Date;
  tokens: number;
  usage: TokenUsage;
  model: string;
  sessionId: string;
}

export interface SessionState {
  sessionId: string;
  slug: string;
  project: string;
  model: string;
  totalInputTokens: number;
  totalOutputTokens: number;
  totalCacheCreationTokens: number;
  totalCacheReadTokens: number;
  firstSeen: Date;
  lastSeen: Date;
}

export interface ModelBreakdown {
  model: string;
  tokens: number;
  costUsd: number;
  sessionCount: number;
  inputTokens: number;
  outputTokens: number;
  cacheCreationTokens: number;
  cacheReadTokens: number;
}

export interface BurnRateStatus {
  serverStartedAt: string;   // ISO timestamp — marks when counting began
  tokensPerSecond: number;
  windowSeconds: number;
  totalTokens: number;
  estimatedCostUsd: number;
  totalSessions: number;
  activeSessions: SessionState[];
  modelBreakdown: ModelBreakdown[];
}

export interface JSONLEntry {
  type: string;
  timestamp: string;
  sessionId: string;
  slug?: string;
  message?: {
    model?: string;
    usage?: {
      input_tokens?: number;
      output_tokens?: number;
      cache_creation_input_tokens?: number;
      cache_read_input_tokens?: number;
    };
  };
  cwd?: string;
}
