import Foundation

class BotAnimator: ObservableObject {
    private enum Threshold {
        static let WORKING_TOKENS_PER_SECOND: Double = 8000
        static let RUNNING_TOKENS_PER_SECOND: Double = 500
        static let WALKING_RECENCY_SECONDS: TimeInterval = 30
    }

    private enum AnimationSpeed {
        static let SLEEPING: Double = 0.8
        static let WALKING: Double  = 2.8
        static let RUNNING: Double  = 11.0
        static let WORKING: Double  = 20.0
        static let LOCKED: Double   = 0.4
    }

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

        if tokensPerSecond > Threshold.WORKING_TOKENS_PER_SECOND {
            currentState = .working
        } else if tokensPerSecond > Threshold.RUNNING_TOKENS_PER_SECOND {
            currentState = .running
        } else if secondsSinceActivity < Threshold.WALKING_RECENCY_SECONDS {
            currentState = .walking
        } else {
            currentState = .sleeping
        }
    }

    func tick() {
        let dt = 1.0 / 24.0
        let speed: Double
        switch currentState {
        case .sleeping: speed = AnimationSpeed.SLEEPING
        case .walking:  speed = AnimationSpeed.WALKING
        case .running:  speed = AnimationSpeed.RUNNING
        case .working:  speed = AnimationSpeed.WORKING
        case .locked:   speed = AnimationSpeed.LOCKED
        }
        animPhase += dt * speed
    }
}
