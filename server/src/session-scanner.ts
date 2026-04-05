import { watch, type FSWatcher } from "fs";
import { readdir, stat } from "fs/promises";
import { join, basename, dirname } from "path";
import { homedir } from "os";
import { parseJSONLLine, extractTokenEvent } from "./jsonl-parser";
import { BurnRateCalculator } from "./burn-rate";

const CLAUDE_DIR = join(homedir(), ".claude", "projects");
const POLL_INTERVAL_MS = 2_000;

interface TrackedFile {
  path: string;
  offset: number;
  sessionId: string;
  project: string;
}

export class SessionScanner {
  private trackedFiles = new Map<string, TrackedFile>();
  private calculator: BurnRateCalculator;
  private pollTimer: ReturnType<typeof setInterval> | null = null;
  private watcher: FSWatcher | null = null;

  constructor(calculator: BurnRateCalculator) {
    this.calculator = calculator;
  }

  async start() {
    // Initial scan
    await this.scanForFiles();

    // Process existing files (only recent data)
    await this.processAllFiles(true);

    // Poll for changes
    this.pollTimer = setInterval(() => this.processAllFiles(false), POLL_INTERVAL_MS);

    // Watch for new files
    try {
      this.watcher = watch(CLAUDE_DIR, { recursive: true }, (event, filename) => {
        if (filename?.endsWith(".jsonl")) {
          this.scanForFiles();
        }
      });
    } catch {
      // Fallback: re-scan periodically if watch fails
      setInterval(() => this.scanForFiles(), 10_000);
    }

    console.log(`[scanner] watching ${CLAUDE_DIR}`);
    console.log(`[scanner] tracking ${this.trackedFiles.size} session files`);
  }

  stop() {
    if (this.pollTimer) clearInterval(this.pollTimer);
    if (this.watcher) this.watcher.close();
  }

  private async scanForFiles() {
    try {
      const projectDirs = await readdir(CLAUDE_DIR);

      for (const projectDir of projectDirs) {
        const projectPath = join(CLAUDE_DIR, projectDir);
        const projectStat = await stat(projectPath).catch(() => null);
        if (!projectStat?.isDirectory()) continue;

        // Top-level session files
        const files = await readdir(projectPath).catch(() => []);
        for (const file of files) {
          if (!file.endsWith(".jsonl")) continue;
          const filePath = join(projectPath, file);

          if (!this.trackedFiles.has(filePath)) {
            const sessionId = basename(file, ".jsonl");
            const project = this.projectNameFromDir(projectDir);

            this.trackedFiles.set(filePath, {
              path: filePath,
              offset: 0,
              sessionId,
              project,
            });
          }
        }

        // Session subdirectories (UUID dirs containing session files)
        for (const entry of files) {
          const entryPath = join(projectPath, entry);
          const entryStat = await stat(entryPath).catch(() => null);
          if (!entryStat?.isDirectory()) continue;
          if (entry === "subagents") continue; // Skip subagent files

          const subFiles = await readdir(entryPath).catch(() => []);
          for (const subFile of subFiles) {
            if (!subFile.endsWith(".jsonl")) continue;
            const filePath = join(entryPath, subFile);

            if (!this.trackedFiles.has(filePath)) {
              const sessionId = basename(subFile, ".jsonl");
              const project = this.projectNameFromDir(projectDir);

              this.trackedFiles.set(filePath, {
                path: filePath,
                offset: 0,
                sessionId,
                project,
              });
            }
          }
        }
      }
    } catch (err) {
      console.error("[scanner] scan error:", err);
    }
  }

  private projectNameFromDir(dirName: string): string {
    // Convert "-Users-caioborghi-personal-my-project" to "my-project"
    const parts = dirName.split("-");
    // Skip the user path prefix, take the last meaningful parts
    const meaningful = parts.slice(3); // Skip "", "Users", "username"
    return meaningful.join("-") || dirName;
  }

  private async processAllFiles(initialScan: boolean) {
    for (const [filePath, tracked] of this.trackedFiles) {
      try {
        const fileStat = await stat(filePath).catch(() => null);
        if (!fileStat) continue;

        const fileSize = fileStat.size;
        if (fileSize <= tracked.offset) continue;

        // On initial scan, only read last 50KB to avoid processing huge histories
        if (initialScan && fileSize > 50_000) {
          tracked.offset = fileSize - 50_000;
        }

        const file = Bun.file(filePath);
        const bytes = await file.slice(tracked.offset, fileSize).arrayBuffer();
        const text = new TextDecoder().decode(bytes);
        const lines = text.split("\n");

        // If we started mid-file (initial scan with offset), skip first partial line
        const startIndex = initialScan && tracked.offset > 0 ? 1 : 0;

        for (let i = startIndex; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line) continue;

          const entry = parseJSONLLine(line);
          if (!entry) continue;

          // Update session metadata
          if (entry.slug) {
            this.calculator.updateSessionMeta(
              entry.sessionId,
              entry.slug,
              tracked.project
            );
          }

          const event = extractTokenEvent(entry);
          if (event) {
            this.calculator.addEvent(event);
          }
        }

        tracked.offset = fileSize;
      } catch (err) {
        // File may have been deleted or be in the middle of a write
      }
    }
  }
}
