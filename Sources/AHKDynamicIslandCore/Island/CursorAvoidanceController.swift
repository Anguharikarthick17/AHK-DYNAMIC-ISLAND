import AppKit
import Foundation
import QuartzCore

/// Coordinates intelligent cursor-aware auto-hide for the Dynamic Island.
/// When the cursor approaches or enters the island's interactive region,
/// the island smoothly hides and passes through all mouse events so underlying
/// controls (such as Chrome tabs or top application buttons) are immediately accessible.
/// When the cursor moves away, the island restores smoothly with anti-flicker hysteresis.
@MainActor
public final class CursorAvoidanceController: NSObject {
    
    public weak var window: IslandWindow?
    public weak var islandView: IslandView?
    public weak var stateManager: IslandStateManager?
    
    public var safetyMargin: CGFloat = 6.0
    public var hideDuration: TimeInterval = 0.15      // 120-180 ms target
    public var restoreDuration: TimeInterval = 0.20   // 180-240 ms target
    public var hysteresisDelay: TimeInterval = 0.30  // 250-400 ms anti-flicker delay
    
    public private(set) var isAvoidanceActive: Bool = false
    private var globalMouseMonitor: Any?
    private var restoreTask: Task<Void, Never>?
    
    public var onPresentationStateChanged: ((IslandPresentationState) -> Void)?
    
    public init(
        window: IslandWindow? = nil,
        islandView: IslandView? = nil,
        stateManager: IslandStateManager? = nil
    ) {
        self.window = window
        self.islandView = islandView
        self.stateManager = stateManager
        super.init()
        
        setupWorkspaceObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    public func cleanup() {
        stopGlobalMonitor()
        restoreTask?.cancel()
        restoreTask = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    private func setupWorkspaceObservers() {
        // Cancel monitor and cleanly reset during display sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetToVisible(animated: false)
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetToVisible(animated: false)
            }
        }
    }
    
    // MARK: - Exclusion Bounds Calculation
    
    public var exclusionFrame: NSRect {
        guard let window = window else { return .zero }
        return window.frame.insetBy(dx: -safetyMargin, dy: -safetyMargin)
    }
    
    // MARK: - Cursor Event Handling
    
    /// Triggered when the cursor enters the Dynamic Island bounds.
    public func handleCursorEntered() {
        guard !isAvoidanceActive else { return }
        
        restoreTask?.cancel()
        restoreTask = nil
        isAvoidanceActive = true
        
        updatePresentationState(.cursorAvoidanceHidden)
        
        // Pass-through: ensure underlying controls (Chrome tabs, menu items) receive clicks
        window?.ignoresMouseEvents = true
        
        animateHide()
        startGlobalMonitor()
    }
    
    /// Triggered when mouse moves; checks whether the cursor is still within the exclusion region.
    public func handleMouseMoved(to screenPoint: NSPoint? = nil) {
        guard isAvoidanceActive else { return }
        
        let mousePoint = screenPoint ?? NSEvent.mouseLocation
        let isInside = exclusionFrame.contains(mousePoint)
        
        if isInside {
            // Cursor remains near or inside the island: cancel pending restore
            restoreTask?.cancel()
            restoreTask = nil
        } else {
            // Cursor moved outside exclusion area: start hysteresis timer
            if restoreTask == nil {
                scheduleRestore()
            }
        }
    }
    
    private func scheduleRestore() {
        restoreTask?.cancel()
        let delayNs = UInt64(hysteresisDelay * 1_000_000_000)
        
        restoreTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, let self = self, self.isAvoidanceActive else { return }
            
            // Re-verify cursor is still outside exclusion region
            let currentPoint = NSEvent.mouseLocation
            if !self.exclusionFrame.contains(currentPoint) {
                self.restoreFromAvoidance()
            } else {
                // False alarm: still inside
                self.restoreTask = nil
            }
        }
    }
    
    private func restoreFromAvoidance() {
        stopGlobalMonitor()
        restoreTask?.cancel()
        restoreTask = nil
        isAvoidanceActive = false
        
        // Restore mouse interactivity for the Dynamic Island
        window?.ignoresMouseEvents = false
        
        updatePresentationState(.visible)
        animateRestore()
    }
    
    public func resetToVisible(animated: Bool = false) {
        stopGlobalMonitor()
        restoreTask?.cancel()
        restoreTask = nil
        isAvoidanceActive = false
        window?.ignoresMouseEvents = false
        updatePresentationState(.visible)
        
        if animated {
            animateRestore()
        } else {
            if let view = islandView?.containerView {
                view.alphaValue = 1.0
                view.layer?.transform = CATransform3DIdentity
            }
        }
    }
    
    // MARK: - Presentation Animations
    
    private func animateHide() {
        guard let view = islandView?.containerView else { return }
        let shouldReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            view.animator().alphaValue = 0.0
            if !shouldReduceMotion {
                let scale = CATransform3DMakeScale(0.96, 0.96, 1.0)
                view.layer?.transform = scale
            }
        }
    }
    
    private func animateRestore() {
        guard let view = islandView?.containerView else { return }
        let shouldReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = restoreDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            view.animator().alphaValue = 1.0
            if !shouldReduceMotion {
                view.layer?.transform = CATransform3DIdentity
            }
        }
    }
    
    private func updatePresentationState(_ state: IslandPresentationState) {
        stateManager?.setPresentationState(state)
        onPresentationStateChanged?(state)
    }
    
    // MARK: - Global Event Monitor Management
    
    private func startGlobalMonitor() {
        guard globalMouseMonitor == nil else { return }
        
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMouseMoved()
            }
        }
    }
    
    private func stopGlobalMonitor() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }
}
