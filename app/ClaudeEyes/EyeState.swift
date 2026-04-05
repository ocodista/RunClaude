import Foundation

enum EyeActivityState: Hashable {
    case sleeping   // No activity for > 30s — robot resting with Z's
    case walking    // Recently active, no tokens — robot walking
    case running    // Tokens flowing — robot running
    case working    // High burn rate — robot with 4 arms all busy
}
