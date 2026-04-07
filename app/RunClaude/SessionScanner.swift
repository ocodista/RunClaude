import Foundation

/// Tails JSONL session files under `~/.claude/projects/` and feeds token events
/// into a `BurnRateEngine`. Polls at a fixed interval — simple and adequate for
/// slowly-growing append-only files.
@MainActor
final class SessionScanner {
    private struct TrackedFile {
        let path: String
        var offset: UInt64
        let sessionId: String
        let project: String
    }

    private struct JSONLUsage: Decodable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_creation_input_tokens: Int?
        let cache_read_input_tokens: Int?
    }

    // Bash tool passes {"command": "..."}, Skill tool passes {"skill": "...", "args": "..."}.
    // We only capture the fields we care about.
    private struct JSONLToolInput: Decodable {
        let command: String?
        let skill: String?
    }

    private struct JSONLContentBlock: Decodable {
        let type: String
        let name: String?         // tool_use: tool name (Bash, Read, Agent, mcp__*, …)
        let id: String?           // tool_use: unique call id
        let tool_use_id: String?  // tool_result: references the originating call
        let is_error: Bool?       // tool_result: true when tool returned an error
        let input: JSONLToolInput? // tool_use: parsed input (Bash command only)
        let text: String?         // text block: the actual text content
    }

    // Claude Code JSONL `content` fields are either a plain string (user text)
    // or an array of typed blocks (tool_use / tool_result / text).
    private enum JSONLContent: Decodable {
        case text(String)
        case blocks([JSONLContentBlock])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let blocks = try? c.decode([JSONLContentBlock].self) {
                self = .blocks(blocks)
            } else {
                self = .text((try? c.decode(String.self)) ?? "")
            }
        }

        var blocks: [JSONLContentBlock] {
            if case .blocks(let b) = self { return b }
            return []
        }

        // Returns the first text content (string body or first text block).
        var firstText: String? {
            switch self {
            case .text(let s): return s.isEmpty ? nil : s
            case .blocks(let blocks): return blocks.first(where: { $0.type == "text" })?.text
            }
        }
    }

    private struct JSONLMessage: Decodable {
        let model: String?
        let usage: JSONLUsage?
        let content: JSONLContent?
    }

    private struct JSONLEntry: Decodable {
        let type: String
        let timestamp: String
        let sessionId: String
        let slug: String?
        let message: JSONLMessage?
    }

    private static let pollInterval: TimeInterval = 2.0
    private static let rescanInterval: TimeInterval = 10.0
    private static let initialTailBytes: UInt64 = 50_000
    // Idle gap thresholds: between 2 min and 2 hours = deliberate pause
    private static let idleMinGap: TimeInterval = 120
    private static let idleMaxGap: TimeInterval = 7200

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    private let engine: BurnRateEngine
    private let claudeDir: URL
    private var tracked: [String: TrackedFile] = [:]
    private var pollTimer: Timer?
    private var rescanTimer: Timer?
    // Last-seen timestamp per session, used to compute idle gaps in-stream.
    private var lastTimestamps: [String: Date] = [:]

    init(engine: BurnRateEngine) {
        self.engine = engine
        self.claudeDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    func start() {
        scanForFiles()
        processAll(initialScan: true)
        engine.refreshSnapshot()

        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.processAll(initialScan: false)
                self.engine.refreshSnapshot()
            }
        }
        rescanTimer = Timer.scheduledTimer(withTimeInterval: Self.rescanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanForFiles()
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        rescanTimer?.invalidate()
        pollTimer = nil
        rescanTimer = nil
    }

    // MARK: - Discovery

    private func scanForFiles() {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(atPath: claudeDir.path) else { return }

        for projectDir in projects {
            let projectURL = claudeDir.appendingPathComponent(projectDir)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectURL.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let projectName = projectName(from: projectDir)
            guard let entries = try? fm.contentsOfDirectory(atPath: projectURL.path) else { continue }

            for entry in entries {
                let entryURL = projectURL.appendingPathComponent(entry)
                var entryIsDir: ObjCBool = false
                guard fm.fileExists(atPath: entryURL.path, isDirectory: &entryIsDir) else { continue }

                if entryIsDir.boolValue {
                    if entry == "subagents" { continue }
                    guard let subFiles = try? fm.contentsOfDirectory(atPath: entryURL.path) else { continue }
                    for subFile in subFiles where subFile.hasSuffix(".jsonl") {
                        track(path: entryURL.appendingPathComponent(subFile).path, project: projectName)
                    }
                } else if entry.hasSuffix(".jsonl") {
                    track(path: entryURL.path, project: projectName)
                }
            }
        }
    }

    private func track(path: String, project: String) {
        guard tracked[path] == nil else { return }
        let sessionId = (path as NSString).lastPathComponent
            .replacingOccurrences(of: ".jsonl", with: "")
        tracked[path] = TrackedFile(path: path, offset: 0, sessionId: sessionId, project: project)
    }

    /// Converts "-Users-caioborghi-personal-my-project" → "my-project".
    private func projectName(from dir: String) -> String {
        let parts = dir.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 3 else { return dir }
        return parts.dropFirst(3).joined(separator: "-")
    }

    // MARK: - Tailing

    private func processAll(initialScan: Bool) {
        for (path, file) in tracked {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = (attrs[.size] as? NSNumber)?.uint64Value else { continue }

            if size <= file.offset { continue }

            // On the very first read, skip to the tail of large files so we
            // don't process months of history.
            var offset = file.offset
            if initialScan && offset == 0 && size > Self.initialTailBytes {
                offset = size - Self.initialTailBytes
            }

            guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { continue }
            defer { try? handle.close() }

            do {
                try handle.seek(toOffset: offset)
            } catch {
                continue
            }

            let data = handle.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { continue }

            // If we skipped into the middle of a line, drop the first partial.
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let startIndex = (initialScan && offset > 0) ? 1 : 0

            if startIndex < lines.count {
                for i in startIndex..<lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    if line.isEmpty { continue }
                    process(line: line, project: file.project)
                }
            }

            var updated = file
            updated.offset = size
            tracked[path] = updated
        }
    }

    private func process(line: String, project: String) {
        guard let data = line.data(using: .utf8),
              let entry = try? JSONDecoder().decode(JSONLEntry.self, from: data) else { return }

        if let slug = entry.slug, !slug.isEmpty {
            engine.updateSessionMeta(sessionId: entry.sessionId, slug: slug, project: project)
        }

        let timestamp = Self.isoWithFraction.date(from: entry.timestamp)
            ?? Self.isoPlain.date(from: entry.timestamp)
            ?? Date()

        // Compute idle gap from the previous message in this session.
        let idleGap: TimeInterval
        if let last = lastTimestamps[entry.sessionId] {
            idleGap = timestamp.timeIntervalSince(last)
        } else {
            idleGap = 0
        }
        lastTimestamps[entry.sessionId] = timestamp

        switch entry.type {
        case "assistant":
            // Token accounting
            if let usage = entry.message?.usage {
                let input       = usage.input_tokens ?? 0
                let output      = usage.output_tokens ?? 0
                let cacheCreate = usage.cache_creation_input_tokens ?? 0
                let cacheRead   = usage.cache_read_input_tokens ?? 0
                let total       = input + output + cacheCreate + cacheRead
                if total > 0 {
                    engine.addEvent(TokenEvent(
                        timestamp: timestamp,
                        tokens: total,
                        usage: TokenUsage(
                            inputTokens: input,
                            outputTokens: output,
                            cacheCreationTokens: cacheCreate,
                            cacheReadTokens: cacheRead
                        ),
                        model: entry.message?.model ?? "unknown",
                        sessionId: entry.sessionId
                    ))
                    // First event for this session won't have a project yet — backfill.
                    engine.updateSessionMeta(sessionId: entry.sessionId, slug: "", project: project)
                }
            }
            // Turn count + idle gap
            engine.recordTurn(sessionId: entry.sessionId, isUser: false, idleGap: idleGap)
            // Tool calls from assistant message content
            for block in entry.message?.content?.blocks ?? [] where block.type == "tool_use" {
                if let name = block.name {
                    engine.addToolCall(
                        sessionId: entry.sessionId,
                        toolName: name,
                        bashCommand: name == "Bash" ? block.input?.command : nil,
                        skillName: name == "Skill" ? block.input?.skill : nil
                    )
                }
            }

        case "user":
            // Turn count + idle gap
            engine.recordTurn(sessionId: entry.sessionId, isUser: true, idleGap: idleGap)
            // Slash command detection from user message text
            if let text = entry.message?.content?.firstText, text.hasPrefix("/") {
                let command = String(text.split(separator: " ").first ?? Substring(text))
                engine.addCommand(sessionId: entry.sessionId, command: command)
            }
            // Error tracking from tool_result blocks
            for block in entry.message?.content?.blocks ?? [] where block.type == "tool_result" {
                if block.is_error == true {
                    engine.addToolError(sessionId: entry.sessionId)
                }
            }

        default:
            break
        }
    }
}
