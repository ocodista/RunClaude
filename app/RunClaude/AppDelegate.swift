import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eyeAnimator: EyeAnimator!
    private var serverClient: ServerClient!
    private var animationTimer: Timer?
    private var pollTimer: Timer?
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
        serverClient = ServerClient()
        eyeAnimator = EyeAnimator()

        let statusView = PopoverView(serverClient: serverClient, eyeAnimator: eyeAnimator)
        popover.contentViewController = NSHostingController(rootView: statusView)

        // Animation loop at ~24fps
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            self?.updateEyes()
        }

        // Poll server every 2 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollServer()
        }

        // Initial poll
        pollServer()

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    private func updateEyes() {
        eyeAnimator.tick()
        let image = EyeRenderer.render(
            state: eyeAnimator.forcedState ?? eyeAnimator.currentState,
            animPhase: eyeAnimator.animPhase
        )
        statusItem.button?.image = image
    }

    private func pollServer() {
        Task {
            if let status = await serverClient.fetchStatus() {
                await MainActor.run {
                    eyeAnimator.updateBurnRate(tokensPerSecond: status.tokensPerSecond)
                }
            }
        }
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Bring popover to front
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        pollTimer?.invalidate()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
