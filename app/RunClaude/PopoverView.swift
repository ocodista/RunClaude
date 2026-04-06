import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case models    = "Models"
    case sessions  = "Sessions"
    case analytics = "Analytics"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .models:    return "cpu"
        case .sessions:  return "terminal.fill"
        case .analytics: return "chart.bar.fill"
        }
    }
}

struct PopoverView: View {
    @ObservedObject var engine: BurnRateEngine
    @ObservedObject var eyeAnimator: EyeAnimator

    @State private var detailTab: DetailTab = .models
    @State private var expandedSessionId: String? = nil

    private var effectiveState: EyeActivityState {
        eyeAnimator.forcedState ?? eyeAnimator.currentState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()

            stateCard
            Divider()

            if let status = engine.status {
                summaryView(status: status)
                Divider()
                detailTabsView
                Divider()
                detailContent(status: status)
            } else {
                loadingView
            }

            Divider()
            debugView
            Divider()
            footerView
        }
        .frame(width: 360)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("RunClaude")
                .font(.headline)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Watching")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - State card

    private var stateCard: some View {
        let info = stateInfo(effectiveState)
        return HStack(spacing: 12) {
            Text(info.emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(info.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(info.color)
                    if eyeAnimator.forcedState != nil {
                        Text("DEBUG")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange))
                    }
                }
                Text(stateSubtitle(effectiveState))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [info.color.opacity(0.08), .clear],
                           startPoint: .leading, endPoint: .trailing)
        )
    }

    private func stateInfo(_ state: EyeActivityState) -> (emoji: String, title: String, color: Color) {
        switch state {
        case .sleeping: return ("😴", "Sleeping",  .gray)
        case .walking:  return ("🚶", "Walking",   .blue)
        case .running:  return ("🏃", "Running",   .green)
        case .working:  return ("⚡️", "Sprinting", .orange)
        }
    }

    private func stateSubtitle(_ state: EyeActivityState) -> String {
        let rate = engine.status?.tokensPerSecond ?? 0
        switch state {
        case .sleeping: return "No activity for 30s+"
        case .walking:  return "Idle • recently active"
        case .running:  return "\(formatTokenRate(rate)) flowing"
        case .working:  return "\(formatTokenRate(rate)) • full throttle 🔥"
        }
    }

    // MARK: - Summary (always visible)

    private func summaryView(status: StatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("Counting since ")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                + Text(countingSinceText(status: status))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                statCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    label: "Burn Rate",
                    value: formatTokenRate(status.tokensPerSecond)
                )
                statCard(
                    icon: "number",
                    iconColor: .blue,
                    label: "Tokens",
                    value: formatTokenCount(status.totalTokens)
                )
                statCard(
                    icon: "dollarsign.circle.fill",
                    iconColor: .green,
                    label: "Est. Cost",
                    value: formatCost(status.totalCostUSD)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func countingSinceText(status: StatusSnapshot) -> String {
        let elapsed = Date().timeIntervalSince(status.serverStartedAt)
        return "\(formatElapsed(elapsed)) ago"
    }

    private func statCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.08)))
    }

    // MARK: - Detail tabs

    private var detailTabsView: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(_ tab: DetailTab) -> some View {
        let isActive = detailTab == tab
        return Button {
            detailTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detailContent(status: StatusSnapshot) -> some View {
        switch detailTab {
        case .models:
            modelsView(status: status)
        case .sessions:
            sessionsView(status: status)
        case .analytics:
            analyticsView(status: status)
        }
    }

    // MARK: - Models tab

    private func modelsView(status: StatusSnapshot) -> some View {
        let models = status.modelBreakdown
        let totalTokens = max(models.map(\.tokens).reduce(0, +), 1)

        return Group {
            if models.isEmpty {
                emptyDetailView(icon: "cpu", text: "No model usage yet")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(models) { m in
                            modelRow(m, share: Double(m.tokens) / Double(totalTokens))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func modelRow(_ m: ModelBreakdown, share: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(modelColor(m.model))
                    .frame(width: 7, height: 7)
                Text(shortModelName(m.model))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(formatTokenCount(m.tokens))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(modelColor(m.model))
                        .frame(width: max(2, geo.size.width * share))
                }
            }
            .frame(height: 4)

            HStack(spacing: 6) {
                Text("\(m.sessionCount) session\(m.sessionCount == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((share * 100).rounded()))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
    }

    private func modelColor(_ model: String) -> Color {
        let lower = model.lowercased()
        if lower.contains("opus")   { return .purple }
        if lower.contains("sonnet") { return .blue }
        if lower.contains("haiku")  { return .teal }
        return .gray
    }

    // MARK: - Sessions tab

    private func sessionsView(status: StatusSnapshot) -> some View {
        Group {
            if status.activeSessions.isEmpty {
                emptyDetailView(icon: "moon.zzz", text: "No active sessions")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(status.activeSessions) { s in
                            sessionCard(s)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func sessionCard(_ session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(modelColor(session.model))
                    .frame(width: 7, height: 7)
                Text(sessionTitle(session))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(shortModelName(session.model))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
            }

            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(session.project.isEmpty ? "unknown" : session.project)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(formatTokenCount(session.totalTokens))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("tokens")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(session.duration < 5 ? "< 5s" : formatElapsed(session.duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(formatCost(session.estimatedCostUSD))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.green)
                if session.errorCount > 0 {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("⚠\(session.errorCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
    }

    private func sessionTitle(_ session: SessionInfo) -> String {
        session.slug.isEmpty ? String(session.sessionId.prefix(8)) : session.slug
    }

    private func shortModelName(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
    }

    // MARK: - Analytics tab

    private func analyticsView(status: StatusSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                analyticsMetricsSection(status: status)
                if !status.topTools.isEmpty {
                    analyticsToolsSection(topTools: status.topTools)
                }
                analyticsSessionsSection(sessions: status.allSessions)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: 260)
    }

    private func analyticsMetricsSection(status: StatusSnapshot) -> some View {
        let totalErrors = status.allSessions.reduce(0) { $0 + $1.errorCount }
        let totalTools  = status.allSessions.reduce(0) { $0 + $1.totalToolCalls }
        let avgDur: TimeInterval = status.allSessions.isEmpty ? 0 :
            status.allSessions.reduce(0.0) { $0 + $1.duration } / Double(status.allSessions.count)

        return HStack(spacing: 6) {
            analyticsStat(label: "Est. Cost",  value: formatCost(status.totalCostUSD), color: .green)
            analyticsStat(label: "Tool Calls", value: "\(totalTools)",                 color: .orange)
            analyticsStat(label: "Errors",     value: "\(totalErrors)",
                          color: totalErrors > 0 ? .red : .secondary)
            analyticsStat(label: "Avg Session",
                          value: avgDur < 5 ? "—" : formatElapsed(avgDur),
                          color: .blue)
        }
    }

    private func analyticsStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.08)))
    }

    private func analyticsToolsSection(topTools: [ToolStat]) -> some View {
        let maxCount = topTools.first?.count ?? 1
        return VStack(alignment: .leading, spacing: 5) {
            analyticsSectionLabel("TOP TOOLS")
            ForEach(Array(topTools.prefix(6))) { tool in
                toolStatRow(tool: tool, maxCount: maxCount)
            }
        }
    }

    private func toolStatRow(tool: ToolStat, maxCount: Int) -> some View {
        HStack(spacing: 8) {
            Text(tool.name)
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.55))
                        .frame(width: max(2, geo.size.width * Double(tool.count) / Double(max(1, maxCount))))
                }
            }
            .frame(height: 5)
            Text("\(tool.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private func analyticsSessionsSection(sessions: [SessionInfo]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            analyticsSectionLabel("SESSIONS (\(sessions.count))")
            if sessions.isEmpty {
                Text("No sessions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions) { session in
                    analyticsSessionRow(session)
                }
            }
        }
    }

    private func analyticsSessionRow(_ session: SessionInfo) -> some View {
        let isExpanded = expandedSessionId == session.id
        return VStack(alignment: .leading, spacing: 2) {
            Button {
                expandedSessionId = isExpanded ? nil : session.id
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(modelColor(session.model))
                            .frame(width: 6, height: 6)
                        Text(sessionTitle(session))
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if session.errorCount > 0 {
                            Text("⚠\(session.errorCount)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 6) {
                        Text(session.project.isEmpty ? "unknown" : session.project)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        Spacer()
                        Text(session.duration < 5 ? "< 5s" : formatElapsed(session.duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 10))
                        Text(formatCost(session.estimatedCostUSD))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.green)
                        if session.totalToolCalls > 0 {
                            Text("·")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 10))
                            Text("\(session.totalToolCalls)t")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
            }
            .buttonStyle(.plain)

            if isExpanded {
                analyticsSessionDetail(session)
            }
        }
    }

    private func analyticsSessionDetail(_ session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if session.toolCounts.isEmpty {
                Text("No tool calls recorded")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                let tools = session.topTools
                ForEach(tools) { tool in
                    HStack {
                        Text(tool.name)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(tool.count) call\(tool.count == 1 ? "" : "s")")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                if session.totalToolCalls > session.topTools.reduce(0, { $0 + $1.count }) {
                    Text("+ \(session.totalToolCalls - session.topTools.reduce(0, { $0 + $1.count })) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("In: \(formatTokenCount(session.totalInputTokens))  Out: \(formatTokenCount(session.totalOutputTokens))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                if session.errorCount > 0 {
                    Text("\(session.errorCount) error\(session.errorCount == 1 ? "" : "s")")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.04))
            .padding(.horizontal, 4))
    }

    private func analyticsSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 1)
    }

    // MARK: - Empty / Loading

    private func emptyDetailView(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 90)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("Scanning sessions…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Debug

    private var debugView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Debug State")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if eyeAnimator.forcedState != nil {
                    Button("Reset") {
                        eyeAnimator.forcedState = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 5) {
                ForEach([EyeActivityState.sleeping, .walking, .running, .working], id: \.self) { state in
                    debugStateButton(state, label: debugLabel(state))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func debugLabel(_ state: EyeActivityState) -> String {
        switch state {
        case .sleeping: return "Sleep"
        case .walking:  return "Walk"
        case .running:  return "Run"
        case .working:  return "Sprint"
        }
    }

    private func debugStateButton(_ state: EyeActivityState, label: String) -> some View {
        let isActive = eyeAnimator.forcedState == state
        let info = stateInfo(state)
        return Button {
            eyeAnimator.forcedState = isActive ? nil : state
        } label: {
            HStack(spacing: 3) {
                Text(info.emoji).font(.system(size: 11))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? info.color.opacity(0.2) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? info.color : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? info.color : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
            Spacer()
            Text("~/.claude/projects")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Formatters

    private func formatTokenRate(_ rate: Double) -> String {
        if rate < 1 { return "0 t/s" }
        if rate < 1000 { return String(format: "%.0f t/s", rate) }
        return String(format: "%.1fk t/s", rate / 1000)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count < 1000 { return "\(count)" }
        if count < 1_000_000 { return String(format: "%.1fk", Double(count) / 1000) }
        return String(format: "%.2fM", Double(count) / 1_000_000)
    }

    private func formatCost(_ usd: Double) -> String {
        if usd < 0.0001 { return "$0.00" }
        if usd < 0.01   { return String(format: "$%.4f", usd) }
        if usd < 1.0    { return String(format: "$%.3f", usd) }
        return String(format: "$%.2f", usd)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60   { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        let h = s / 3600
        let m = (s % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
