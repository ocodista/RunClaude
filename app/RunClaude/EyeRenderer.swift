import AppKit

struct EyeRenderer {
    static let iconWidth: CGFloat = 34
    static let iconHeight: CGFloat = 18

    // Ground reference line (flipped coords: y grows downward)
    private static let groundY: CGFloat = 15.8
    private static let legLength: CGFloat = 4.6

    static func render(state: EyeActivityState, animPhase: Double) -> NSImage {
        let image = NSImage(size: NSSize(width: iconWidth, height: iconHeight), flipped: true) { _ in
            let p = CGFloat(animPhase)

            NSColor.black.setStroke()
            NSColor.black.setFill()

            switch state {
            case .sleeping:
                drawSleeping(phase: p)
            case .walking:
                drawRunner(phase: p, tier: .walk)
            case .running:
                drawRunner(phase: p, tier: .run)
            case .working:
                drawRunner(phase: p, tier: .sprint)
            case .locked:
                drawLocked(phase: p)
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    // MARK: - Running / Walking (seamless loop)

    enum RunTier {
        case walk, run, sprint

        var swingAmp: CGFloat {
            switch self {
            case .walk:   return 0.55
            case .run:    return 0.95
            case .sprint: return 1.15
            }
        }
        var bobAmp: CGFloat {
            switch self {
            case .walk:   return 0.45
            case .run:    return 1.1
            case .sprint: return 1.4
            }
        }
        var lean: CGFloat {
            switch self {
            case .walk:   return 0.5
            case .run:    return 1.4
            case .sprint: return 2.0
            }
        }
        var hasMotionLines: Bool { self == .sprint }
    }

    private static func drawRunner(phase: CGFloat, tier: RunTier) {
        // Character stays centered in the menu bar (like RunCat) — only the limbs animate.
        // sin(phase) has period 2π, so the swing naturally loops forever.
        let x: CGFloat = iconWidth / 2 - 1  // slightly left of center to balance the forward lean
        let swing = sin(phase) * tier.swingAmp

        // Upward bounce on every step (always lifts up, never sinks)
        let bob = abs(sin(phase)) * tier.bobAmp

        let hipY = groundY - legLength - bob
        let shoulderY = hipY - 2.7
        let headCY = shoulderY - 2.5

        let lean = tier.lean
        let headX = x + lean
        let shoulderX = x + lean * 0.7
        let hipX = x

        // Motion lines trailing the sprint for a "going fast" effect
        if tier.hasMotionLines {
            drawMotionLines(atX: x, hipY: hipY, shoulderY: shoulderY)
        }

        // Head
        drawHead(cx: headX, cy: headCY, closedEye: false)

        // Neck
        line(from: CGPoint(x: headX - 0.2, y: headCY + 2.1),
             to: CGPoint(x: shoulderX, y: shoulderY - 0.1),
             width: 1.0)

        // Torso (filled trapezoid)
        drawTorso(shoulderX: shoulderX, shoulderY: shoulderY, hipX: hipX, hipY: hipY)

        // Legs — right leg in-phase with swing, left leg anti-phase
        drawLeg(hipX: hipX, hipY: hipY, swing:  swing, length: legLength)
        drawLeg(hipX: hipX, hipY: hipY, swing: -swing, length: legLength)

        // Arms — opposite to same-side legs
        let armAnchor = CGPoint(x: shoulderX, y: shoulderY + 0.3)
        drawArm(shoulder: armAnchor, swing: -swing * 0.75, length: 3.0)
        drawArm(shoulder: armAnchor, swing:  swing * 0.75, length: 3.0)
    }

    // MARK: - Sleeping

    private static func drawSleeping(phase: CGFloat) {
        let cx: CGFloat = iconWidth / 2 - 3
        // Gentle breathing sway
        let sway = sin(phase) * 0.25
        let hipY = groundY - legLength
        let shoulderY = hipY - 2.7
        let headCY = shoulderY - 2.3 + 0.4 // head droops slightly forward

        // Head (tilted slightly)
        drawHead(cx: cx + sway + 0.3, cy: headCY, closedEye: true)

        // Neck
        line(from: CGPoint(x: cx + sway * 0.5 + 0.2, y: headCY + 2.1),
             to: CGPoint(x: cx, y: shoulderY - 0.1), width: 1.0)

        // Torso
        drawTorso(shoulderX: cx, shoulderY: shoulderY, hipX: cx, hipY: hipY)

        // Arms drooping
        line(from: CGPoint(x: cx - 1.5, y: shoulderY + 0.4),
             to: CGPoint(x: cx - 2.4, y: hipY + 0.6), width: 1.1)
        line(from: CGPoint(x: cx + 1.5, y: shoulderY + 0.4),
             to: CGPoint(x: cx + 2.4, y: hipY + 0.6), width: 1.1)

        // Legs standing
        drawStandingLegs(hipX: cx, hipY: hipY)

        // Floating Z's
        drawZs(baseX: cx + 3, baseY: headCY - 2.2, phase: phase)
    }

    // MARK: - Motion lines (sprint effect)

    private static func drawMotionLines(atX x: CGFloat, hipY: CGFloat, shoulderY: CGFloat) {
        // Three small horizontal dashes trailing behind the runner
        let dashes: [(dx: CGFloat, y: CGFloat, len: CGFloat, alpha: CGFloat)] = [
            (-3.5, shoulderY + 0.5, 2.5, 0.9),
            (-5.0, (shoulderY + hipY) / 2, 3.0, 0.55),
            (-3.8, hipY + 0.2, 2.3, 0.7)
        ]
        for d in dashes {
            NSColor.black.withAlphaComponent(d.alpha).setStroke()
            line(from: CGPoint(x: x + d.dx, y: d.y),
                 to: CGPoint(x: x + d.dx - d.len, y: d.y),
                 width: 0.9)
        }
        NSColor.black.setStroke()
    }

    // MARK: - Pieces

    private static func drawHead(cx: CGFloat, cy: CGFloat, closedEye: Bool) {
        let r: CGFloat = 2.3
        let head = NSBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        head.lineWidth = 1.3
        head.stroke()

        if closedEye {
            // Closed eye — small horizontal tick on the right side (facing right)
            line(from: CGPoint(x: cx + 0.2, y: cy - 0.1),
                 to: CGPoint(x: cx + 1.4, y: cy - 0.1), width: 0.9)
        } else {
            // Open eye dot on the right side (facing right)
            let eyeR: CGFloat = 0.7
            NSBezierPath(ovalIn: CGRect(x: cx + 0.75 - eyeR, y: cy - 0.25 - eyeR,
                                        width: eyeR * 2, height: eyeR * 2)).fill()
        }
    }

    private static func drawTorso(shoulderX: CGFloat, shoulderY: CGFloat, hipX: CGFloat, hipY: CGFloat) {
        let shoulderW: CGFloat = 3.4
        let hipW: CGFloat = 2.6
        let path = NSBezierPath()
        path.move(to: CGPoint(x: shoulderX - shoulderW / 2, y: shoulderY))
        path.line(to: CGPoint(x: shoulderX + shoulderW / 2, y: shoulderY))
        path.line(to: CGPoint(x: hipX + hipW / 2, y: hipY))
        path.line(to: CGPoint(x: hipX - hipW / 2, y: hipY))
        path.close()
        path.fill()
    }

    /// Leg with subtle knee bend. `swing > 0` = leg forward (toward +x).
    private static func drawLeg(hipX: CGFloat, hipY: CGFloat, swing: CGFloat, length: CGFloat) {
        let angle = swing * 1.1
        let kneeX = hipX + sin(angle * 0.55) * length * 0.5 + (swing * 0.25)
        let kneeY = hipY + cos(angle * 0.55) * length * 0.5
        let footX = hipX + sin(angle) * length
        let footY = hipY + cos(angle) * length

        line(from: CGPoint(x: hipX, y: hipY), to: CGPoint(x: kneeX, y: kneeY), width: 1.4)
        line(from: CGPoint(x: kneeX, y: kneeY), to: CGPoint(x: footX, y: footY), width: 1.4)
        // Foot — tiny horizontal tick pointing forward
        line(from: CGPoint(x: footX - 0.2, y: footY),
             to: CGPoint(x: footX + 1.3, y: footY), width: 1.2)
    }

    /// Arm with subtle elbow bend.
    private static func drawArm(shoulder: CGPoint, swing: CGFloat, length: CGFloat) {
        let angle = swing * 1.3
        let elbowX = shoulder.x + sin(angle * 0.55) * length * 0.55
        let elbowY = shoulder.y + cos(angle * 0.55) * length * 0.55
        let handX = shoulder.x + sin(angle) * length
        let handY = shoulder.y + cos(angle) * length * 0.95

        line(from: shoulder, to: CGPoint(x: elbowX, y: elbowY), width: 1.1)
        line(from: CGPoint(x: elbowX, y: elbowY), to: CGPoint(x: handX, y: handY), width: 1.1)
    }

    private static func drawStandingLegs(hipX: CGFloat, hipY: CGFloat) {
        // Two parallel straight legs, feet ticks at ground
        let footY = hipY + legLength
        line(from: CGPoint(x: hipX - 0.8, y: hipY), to: CGPoint(x: hipX - 1.0, y: footY), width: 1.4)
        line(from: CGPoint(x: hipX + 0.8, y: hipY), to: CGPoint(x: hipX + 1.0, y: footY), width: 1.4)
        line(from: CGPoint(x: hipX - 1.8, y: footY), to: CGPoint(x: hipX - 0.2, y: footY), width: 1.2)
        line(from: CGPoint(x: hipX + 0.2, y: footY), to: CGPoint(x: hipX + 1.8, y: footY), width: 1.2)
    }

    // MARK: - Locked (behind bars)

    private static func drawLocked(phase: CGFloat) {
        // Very slow weight-shift sway (bored)
        let sway = sin(phase * 0.5) * 0.18
        let cx: CGFloat = iconWidth / 2 - 5
        let hipY      = groundY - legLength
        let shoulderY = hipY - 2.7
        let headCY    = shoulderY - 2.3

        // Head with bored squinting eyes
        let r: CGFloat = 2.3
        let headPath = NSBezierPath(ovalIn: CGRect(x: cx + sway - r, y: headCY - r, width: r * 2, height: r * 2))
        headPath.lineWidth = 1.3
        headPath.stroke()
        line(from: CGPoint(x: cx + sway - 1.1, y: headCY - 0.25),
             to:   CGPoint(x: cx + sway - 0.3, y: headCY - 0.25), width: 0.8)
        line(from: CGPoint(x: cx + sway + 0.3, y: headCY - 0.25),
             to:   CGPoint(x: cx + sway + 1.1, y: headCY - 0.25), width: 0.8)

        // Neck
        line(from: CGPoint(x: cx + sway * 0.5, y: headCY + 2.1),
             to:   CGPoint(x: cx, y: shoulderY - 0.1), width: 1.0)

        // Torso
        drawTorso(shoulderX: cx, shoulderY: shoulderY, hipX: cx, hipY: hipY)

        // Arms drooping at sides
        line(from: CGPoint(x: cx - 1.5, y: shoulderY + 0.4),
             to:   CGPoint(x: cx - 2.1, y: hipY + 0.9), width: 1.1)
        line(from: CGPoint(x: cx + 1.5, y: shoulderY + 0.4),
             to:   CGPoint(x: cx + 2.1, y: hipY + 0.9), width: 1.1)

        // Standing legs
        drawStandingLegs(hipX: cx, hipY: hipY)

        // Prison bars drawn in front of the figure
        let barXs: [CGFloat] = [11.0, 14.5, 18.0, 21.5]
        for bx in barXs {
            NSBezierPath(roundedRect: CGRect(x: bx - 0.65, y: 0.8,
                                             width: 1.3, height: groundY + 0.5),
                         xRadius: 0.3, yRadius: 0.3).fill()
        }
    }

    // MARK: - Z's (sleeping)

    private static func drawZs(baseX: CGFloat, baseY: CGFloat, phase: CGFloat) {
        let cycleLen = CGFloat.pi * 4  // slower cycle
        for i in 0..<2 {
            let offset = CGFloat(i) * CGFloat.pi * 2
            let t = fmod(phase * 0.6 + offset, cycleLen) / cycleLen  // 0..1
            let floatY = -t * 3.0       // upward (negative y in flipped coords)
            let size: CGFloat = 2.0 - CGFloat(i) * 0.5
            let zx = baseX + CGFloat(i) * 1.4
            let zy = baseY + floatY

            let alpha = min(t * 4.0, (1.0 - t) * 2.5, 1.0)
            NSColor.black.withAlphaComponent(alpha).setStroke()

            let z = NSBezierPath()
            z.move(to: CGPoint(x: zx, y: zy))
            z.line(to: CGPoint(x: zx + size, y: zy))
            z.line(to: CGPoint(x: zx, y: zy + size))
            z.line(to: CGPoint(x: zx + size, y: zy + size))
            z.lineWidth = 0.8
            z.stroke()
        }
        NSColor.black.setStroke()
    }

    // MARK: - Line helper

    private static func line(from: CGPoint, to: CGPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: from)
        path.line(to: to)
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }
}
