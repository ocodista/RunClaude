import { BurnRateCalculator } from "./burn-rate";
import { SessionScanner } from "./session-scanner";
import type { BurnRateStatus } from "./types";

const PORT = 17888;

const calculator = new BurnRateCalculator();
const scanner = new SessionScanner(calculator);

await scanner.start();

const server = Bun.serve({
  port: PORT,
  fetch(req) {
    const url = new URL(req.url);

    if (url.pathname === "/status") {
      const status: BurnRateStatus = {
        tokensPerSecond: calculator.getTokensPerSecond(),
        activeSessions: calculator.getActiveSessions(),
        totalTokens: calculator.getTotalTokens(),
        estimatedCostUsd: calculator.getEstimatedCost(),
        windowSeconds: 60,
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

console.log(`[claude-eyes] server running on http://localhost:${PORT}`);
console.log(`[claude-eyes] GET /status for token burn rate`);
