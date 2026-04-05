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

export interface BurnRateStatus {
  tokensPerSecond: number;
  activeSessions: SessionState[];
  totalTokens: number;
  estimatedCostUsd: number;
  windowSeconds: number;
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
