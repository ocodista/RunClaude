import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var botAnimator: BotAnimator!
    private var engine: BurnRateEngine!
    private var scanner: SessionScanner!
    private var statsStore: StatsStore!
    private var animationTimer: Timer?
    private var mergeTimer: Timer?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 34)

        if let button = statusItem.button {
            button.image = BotRenderer.render(state: .sleeping, animPhase: 0)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 560)
        popover.behavior = .transient

        engine = BurnRateEngine()
        scanner = SessionScanner(engine: engine)
        botAnimator = BotAnimator()
        statsStore = StatsStore()

        let statusView = PopoverView(engine: engine, botAnimator: botAnimator, statsStore: statsStore)
        popover.contentViewController = NSHostingController(rootView: statusView)

        scanner.start()

        // Initial merge after scanner has processed the tail
        statsStore.merge(liveDays: engine.liveDailyBuckets())

        // Merge + save every 30 seconds
        mergeTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.statsStore.merge(liveDays: self.engine.liveDailyBuckets())
                self.statsStore.save()
            }
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    private func tick() {
        botAnimator.updateBurnRate(tokensPerSecond: engine.status?.tokensPerSecond ?? 0,
                                   isRateLimited: engine.status?.isRateLimited ?? false)
        botAnimator.tick()
        let image = BotRenderer.render(
            state: botAnimator.forcedState ?? botAnimator.currentState,
            animPhase: botAnimator.animPhase
        )
        statusItem.button?.image = image
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Sync store before showing
                statsStore.merge(liveDays: engine.liveDailyBuckets())
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statsStore.merge(liveDays: engine.liveDailyBuckets())
        statsStore.save()
        animationTimer?.invalidate()
        mergeTimer?.invalidate()
        scanner?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
