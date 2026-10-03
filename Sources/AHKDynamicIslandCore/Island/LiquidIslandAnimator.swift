import AppKit
import Foundation
import QuartzCore

/// Motion and shine orchestrator for AHK Dynamic Island.
/// Manages physical spring morphing, single-shot activity specular sweeps,
/// and low-frequency scheduled idle sweeps with 0% background CPU impact.
@MainActor
public final class LiquidIslandAnimator {
    
    public weak var surface: LiquidIslandSurface?
    
    private var idleSweepTask: Task<Void, Never>?
    private var isIdleActive: Bool = false
    private var isIslandVisible: Bool = true
    
    public init(surface: LiquidIslandSurface? = nil) {
        self.surface = surface
        setupScreenNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupScreenNotifications() {
        // Stop all animations if screens sleep or lock
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pauseIdleAnimation()
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.isIdleActive == true {
                    self?.resumeIdleAnimation()
                }
            }
        }
    }
    
    // MARK: - State & Visibility
    
    public func setVisibility(isVisible: Bool) {
        self.isIslandVisible = isVisible
        if !isVisible {
            pauseIdleAnimation()
            surface?.stopAllShine()
        } else if isIdleActive {
            resumeIdleAnimation()
        }
    }
    
    public func updateActivityState(_ activity: IslandActivity) {
        let isIdle = (activity == .idle)
        self.isIdleActive = isIdle
        
        if isIdle {
            // Returning to idle: start scheduled idle sweep cadence
            resumeIdleAnimation()
        } else {
            // Real activity started: halt idle scheduler and fire ONE activity shine
            pauseIdleAnimation()
            triggerActivityShine()
        }
    }
    
    // MARK: - Activity Shine
    
    /// Triggers one single specular light sweep + border highlight for an activity transition.
    public func triggerActivityShine() {
        guard isIslandVisible else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        surface?.performActivityShine()
    }
    
    // MARK: - Scheduled Idle Sweep
    
    public func resumeIdleAnimation() {
        guard isIslandVisible else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        
        idleSweepTask?.cancel()
        idleSweepTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // Low frequency: 7.5 to 8.5 second cadence
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled, let self = self, self.isIdleActive, self.isIslandVisible else { break }
                
                self.surface?.performIdleShine()
            }
        }
    }
    
    public func pauseIdleAnimation() {
        idleSweepTask?.cancel()
        idleSweepTask = nil
        surface?.stopAllShine()
    }
}
