import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case models = "Models"
    case sessions = "Sessions"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .models:   return "cpu"
        case .sessions: return "terminal.fill"
        }
    }
}

struct PopoverView: View {
    @ObservedObject var serverClient: ServerClient
    @ObservedObject var eyeAnimator: EyeAnimator

    @State private var detailTab: DetailTab = .models

    private var effectiveState: EyeActivityState {
        eyeAnimator.forcedState ?? eyeAnimator.currentState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()

            stateCard
            Divider()

            if let status = serverClient.status {
                summaryView(status: status)
                Divider()
                detailTabsView
                Divider()
                detailContent(status: status)
            } else if !serverClient.isConnected {
                disconnectedView
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
                    .fill(serverClient.isConnected ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text(serverClient.isConnected ? "Connected" : "Offline")
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
        let rate = serverClient.status?.tokensPerSecond ?? 0
        switch state {
        case .sleeping: return "No activity for 30s+"
        case .walking:  return "Idle • recently active"
        case .running:  return "\(formatTokenRate(rate)) flowing"
        case .working:  return "\(formatTokenRate(rate)) • full throttle 🔥"
        }
    }

    // MARK: - Summary (always visible)

    private func summaryView(status: StatusResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Counting-since line
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
                    label: "Cost",
                    value: formatCost(status.estimatedCostUsd)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func countingSinceText(status: StatusResponse) -> String {
        guard let date = status.serverStartedAtDate else { return "server start" }
        let elapsed = Date().timeIntervalSince(date)
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
    private func detailContent(status: StatusResponse) -> some View {
        switch detailTab {
        case .models:
            modelsView(status: status)
        case .sessions:
            sessionsView(status: status)
        }
    }

    // MARK: - Models tab

    private func modelsView(status: StatusResponse) -> some View {
        let models = status.modelBreakdown
        let totalCost = max(models.map(\.costUsd).reduce(0, +), 0.0001)

        return Group {
            if models.isEmpty {
                emptyDetailView(icon: "cpu", text: "No model usage yet")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(models) { m in
                            modelRow(m, share: m.costUsd / totalCost)
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
                Text(formatCost(m.costUsd))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            // Share bar
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
                Text("\(formatTokenCount(m.tokens)) tokens")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
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

    private func sessionsView(status: StatusResponse) -> some View {
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
                Text(session.project)
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

    // MARK: - Empty / Disconnected

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

    private var disconnectedView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "network.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Server not running")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Run: cd server && bun dev")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
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
            Text("localhost:17888")
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

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 { return "$0.00" }
        if cost < 100  { return String(format: "$%.2f", cost) }
        return String(format: "$%.0f", cost)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60  { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        let h = s / 3600
        let m = (s % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
