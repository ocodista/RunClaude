#!/usr/bin/env swift
// Generates AppIcon.icns from a high-resolution rendering of the sprint stick figure.
// Usage: swift generate-icon.swift

import AppKit

let canvasSize: CGFloat = 1024
let scale: CGFloat = 42  // scale factor from 18px menu bar to 1024px icon

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
        // Background — rounded rect with gradient
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2),
                                  xRadius: size * 0.18, yRadius: size * 0.18)

        let gradient = NSGradient(
            starting: NSColor(calibratedRed: 0.38, green: 0.22, blue: 0.85, alpha: 1.0),
            ending:   NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.95, alpha: 1.0)
        )
        gradient?.draw(in: bgPath, angle: -45)

        // Center the figure
        let cx = size * 0.46
        let groundY = size * 0.78

        let legLength: CGFloat = 4.6 * scale
        let phase: CGFloat = 0.85  // frozen mid-stride

        let swing = sin(phase) * 1.15  // sprint amplitude
        let bob = abs(sin(phase)) * 1.4 * scale

        let hipY = groundY - legLength - bob
        let shoulderY = hipY - 2.7 * scale
        let headCY = shoulderY - 2.5 * scale

        let lean: CGFloat = 2.0 * scale
        let headX = cx + lean
        let shoulderX = cx + lean * 0.7
        let hipX = cx

        NSColor.white.setStroke()
        NSColor.white.setFill()

        let lw: CGFloat = 1.3 * scale  // base line width

        // Motion lines
        let dashes: [(dx: CGFloat, y: CGFloat, len: CGFloat, alpha: CGFloat)] = [
            (-3.5 * scale, shoulderY + 0.5 * scale, 2.5 * scale, 0.9),
            (-5.0 * scale, (shoulderY + hipY) / 2, 3.0 * scale, 0.55),
            (-3.8 * scale, hipY + 0.2 * scale, 2.3 * scale, 0.7)
        ]
        for d in dashes {
            NSColor.white.withAlphaComponent(d.alpha).setStroke()
            strokeLine(from: CGPoint(x: cx + d.dx, y: d.y),
                       to: CGPoint(x: cx + d.dx - d.len, y: d.y),
                       width: 0.9 * scale)
        }
        NSColor.white.setStroke()

        // Head
        let headR: CGFloat = 2.3 * scale
        let head = NSBezierPath(ovalIn: CGRect(x: headX - headR, y: headCY - headR,
                                               width: headR * 2, height: headR * 2))
        head.lineWidth = lw
        head.stroke()

        // Eye
        let eyeR: CGFloat = 0.7 * scale
        NSBezierPath(ovalIn: CGRect(x: headX + 0.75 * scale - eyeR,
                                     y: headCY - 0.25 * scale - eyeR,
                                     width: eyeR * 2, height: eyeR * 2)).fill()

        // Neck
        strokeLine(from: CGPoint(x: headX - 0.2 * scale, y: headCY + 2.1 * scale),
                   to: CGPoint(x: shoulderX, y: shoulderY - 0.1 * scale),
                   width: 1.0 * scale)

        // Torso
        let shoulderW: CGFloat = 3.4 * scale
        let hipW: CGFloat = 2.6 * scale
        let torso = NSBezierPath()
        torso.move(to: CGPoint(x: shoulderX - shoulderW / 2, y: shoulderY))
        torso.line(to: CGPoint(x: shoulderX + shoulderW / 2, y: shoulderY))
        torso.line(to: CGPoint(x: hipX + hipW / 2, y: hipY))
        torso.line(to: CGPoint(x: hipX - hipW / 2, y: hipY))
        torso.close()
        torso.fill()

        // Legs
        drawLeg(hipX: hipX, hipY: hipY, swing: swing, length: legLength, lw: lw)
        drawLeg(hipX: hipX, hipY: hipY, swing: -swing, length: legLength, lw: lw)

        // Arms
        let armAnchor = CGPoint(x: shoulderX, y: shoulderY + 0.3 * scale)
        drawArm(shoulder: armAnchor, swing: -swing * 0.75, length: 3.0 * scale, lw: lw)
        drawArm(shoulder: armAnchor, swing: swing * 0.75, length: 3.0 * scale, lw: lw)

        return true
    }
}

func drawLeg(hipX: CGFloat, hipY: CGFloat, swing: CGFloat, length: CGFloat, lw: CGFloat) {
    let angle = swing * 1.1
    let kneeX = hipX + sin(angle * 0.55) * length * 0.5 + (swing * 0.25 * scale)
    let kneeY = hipY + cos(angle * 0.55) * length * 0.5
    let footX = hipX + sin(angle) * length
    let footY = hipY + cos(angle) * length

    strokeLine(from: CGPoint(x: hipX, y: hipY), to: CGPoint(x: kneeX, y: kneeY), width: 1.4 * scale)
    strokeLine(from: CGPoint(x: kneeX, y: kneeY), to: CGPoint(x: footX, y: footY), width: 1.4 * scale)
    strokeLine(from: CGPoint(x: footX - 0.2 * scale, y: footY),
               to: CGPoint(x: footX + 1.3 * scale, y: footY), width: 1.2 * scale)
}

func drawArm(shoulder: CGPoint, swing: CGFloat, length: CGFloat, lw: CGFloat) {
    let angle = swing * 1.3
    let elbowX = shoulder.x + sin(angle * 0.55) * length * 0.55
    let elbowY = shoulder.y + cos(angle * 0.55) * length * 0.55
    let handX = shoulder.x + sin(angle) * length
    let handY = shoulder.y + cos(angle) * length * 0.95

    strokeLine(from: shoulder, to: CGPoint(x: elbowX, y: elbowY), width: 1.1 * scale)
    strokeLine(from: CGPoint(x: elbowX, y: elbowY), to: CGPoint(x: handX, y: handY), width: 1.1 * scale)
}

func strokeLine(from: CGPoint, to: CGPoint, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    path.lineWidth = width
    path.lineCapStyle = .round
    path.stroke()
}

// --- Generate ---

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let iconsetDir = "\(scriptDir)/AppIcon.iconset"

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

// Render at 1024 then downscale
let master = drawIcon(size: canvasSize)

for entry in sizes {
    let sz = NSSize(width: entry.px, height: entry.px)
    let resized = NSImage(size: sz, flipped: false) { rect in
        master.draw(in: rect)
        return true
    }

    guard let tiff = resized.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to render \(entry.name)")
        continue
    }

    let outPath = "\(iconsetDir)/\(entry.name).png"
    try png.write(to: URL(fileURLWithPath: outPath))
}

// Convert to icns
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", "\(scriptDir)/AppIcon.icns"]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    try? fm.removeItem(atPath: iconsetDir)
    print("Generated: \(scriptDir)/AppIcon.icns")
} else {
    print("iconutil failed with status \(proc.terminationStatus)")
}
