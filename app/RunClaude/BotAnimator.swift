import Foundation

class BotAnimator: ObservableObject {
    private(set) var currentState: BotState = .sleeping
    private(set) var animPhase: Double = 0

    /// When set, overrides the auto-detected state (debug use only).
    @Published var forcedState: BotState? = nil

    private var tokensPerSecond: Double = 0
    private var lastActivityTime: Date = .distantPast

    func updateBurnRate(tokensPerSecond: Double, isRateLimited: Bool = false) {
        self.tokensPerSecond = tokensPerSecond

        if isRateLimited {
            currentState = .locked
            return
        }

        if tokensPerSecond > 0 { lastActivityTime = Date() }
        let secondsSinceActivity = Date().timeIntervalSince(lastActivityTime)

        if tokensPerSecond > 2000      { currentState = .working }
        else if tokensPerSecond > 10   { currentState = .running }
        else if secondsSinceActivity < 30 { currentState = .walking }
        else                           { currentState = .sleeping }
    }

    func tick() {
        let dt = 1.0 / 24.0
        let speed: Double
        switch currentState {
        case .sleeping: speed = 0.8
        case .walking:  speed = 2.8
        case .running:  speed = 11.0
        case .working:  speed = 20.0
        case .locked:   speed = 0.4   // Very slow bored sway
        }
        animPhase += dt * speed
    }
}
