import { BurnRateCalculator } from "./burn-rate";
import { SessionScanner } from "./session-scanner";
import type { BurnRateStatus } from "./types";

const PORT = 17888;

const calculator = new BurnRateCalculator();
const scanner = new SessionScanner(calculator);
const serverStartedAt = new Date().toISOString();

await scanner.start();

const server = Bun.serve({
  port: PORT,
  fetch(req) {
    const url = new URL(req.url);

    if (url.pathname === "/status") {
      const status: BurnRateStatus = {
        serverStartedAt,
        tokensPerSecond: calculator.getTokensPerSecond(),
        windowSeconds: 60,
        totalTokens: calculator.getTotalTokens(),
        estimatedCostUsd: calculator.getEstimatedCost(),
        totalSessions: calculator.getTotalSessions(),
        activeSessions: calculator.getActiveSessions(),
        modelBreakdown: calculator.getModelBreakdown(),
      };

      return Response.json(status, {
        headers: { "Access-Control-Allow-Origin": "*" },
      });
    }

    if (url.pathname === "/health") {
      return Response.json({ ok: true });
    }

    return new Response("Not found", { status: 404 });
  },
});

console.log(`[runclaude] server running on http://localhost:${PORT}`);
console.log(`[runclaude] GET /status for token burn rate`);
