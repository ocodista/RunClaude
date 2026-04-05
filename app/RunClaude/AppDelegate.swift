import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eyeAnimator: EyeAnimator!
    private var engine: BurnRateEngine!
    private var scanner: SessionScanner!
    private var animationTimer: Timer?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: 34)

        if let button = statusItem.button {
            button.image = EyeRenderer.render(state: .sleeping, animPhase: 0)
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Set up popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient

        // Initialize services
        engine = BurnRateEngine()
        scanner = SessionScanner(engine: engine)
        eyeAnimator = EyeAnimator()

        let statusView = PopoverView(engine: engine, eyeAnimator: eyeAnimator)
        popover.contentViewController = NSHostingController(rootView: statusView)

        // Start tailing Claude session files
        scanner.start()

        // Animation loop at ~24fps — also pulls the latest burn rate from the engine.
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    private func tick() {
        eyeAnimator.updateBurnRate(tokensPerSecond: engine.status?.tokensPerSecond ?? 0)
        eyeAnimator.tick()
        let image = EyeRenderer.render(
            state: eyeAnimator.forcedState ?? eyeAnimator.currentState,
            animPhase: eyeAnimator.animPhase
        )
        statusItem.button?.image = image
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        scanner?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
