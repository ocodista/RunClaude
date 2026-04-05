import SwiftUI

struct PopoverView: View {
    @ObservedObject var serverClient: ServerClient
    @ObservedObject var eyeAnimator: EyeAnimator

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
                statsView(status: status)
                Divider()

                if !status.activeSessions.isEmpty {
                    sessionsView(sessions: status.activeSessions)
                } else {
                    emptySessionsView
                }
            } else if !serverClient.isConnected {
                disconnectedView
            }

            Divider()
            debugView
            Divider()
            footerView
        }
        .frame(width: 340)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("Claude Eyes")
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

    // MARK: - Current state card

    private var stateCard: some View {
        let info = stateInfo(effectiveState)
        return HStack(spacing: 12) {
            Text(info.emoji)
                .font(.system(size: 30))
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
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange)
                            )
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
            LinearGradient(
                colors: [info.color.opacity(0.08), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
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

    // MARK: - Stats

    private func statsView(status: StatusResponse) -> some View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Sessions

    private func sessionsView(sessions: [SessionInfo]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Active Sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(sessions.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(sessions) { session in
                        sessionCard(session: session)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: 180)
        }
    }

    private func sessionCard(session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
                Text(sessionTitle(session))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                modelBadge(session.model)
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func sessionTitle(_ session: SessionInfo) -> String {
        session.slug.isEmpty ? String(session.sessionId.prefix(8)) : session.slug
    }

    private func modelBadge(_ model: String) -> some View {
        Text(shortModelName(model))
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
            )
    }

    private func shortModelName(_ model: String) -> String {
        // "claude-opus-4-6" -> "opus-4.6"
        let trimmed = model.replacingOccurrences(of: "claude-", with: "")
        // Replace last "-N-M" with ".N.M"-ish
        return trimmed
    }

    // MARK: - Empty / Disconnected

    private var emptySessionsView: some View {
        VStack(spacing: 4) {
            Spacer()
            Image(systemName: "moon.zzz")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No active sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
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
                Text(info.emoji)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
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
        return String(format: "$%.2f", cost)
    }
}
