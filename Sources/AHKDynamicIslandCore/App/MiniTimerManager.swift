import Foundation

/// Lightweight, elapsed-time-accurate timer manager for dynamic island countdowns.
@MainActor
public final class MiniTimerManager {
    
    public static let shared = MiniTimerManager()
    
    public private(set) var activeTimerDuration: TimeInterval?
    public private(set) var targetEndTime: Date?
    public private(set) var isPaused: Bool = false
    
    private var pausedRemaining: TimeInterval?
    private var countdownTimer: Timer?
    
    public var onTick: ((_ remaining: TimeInterval, _ total: TimeInterval) -> Void)?
    public var onComplete: ((_ total: TimeInterval) -> Void)?
    public var onCancelled: (() -> Void)?
    
    public init() {}
    
    public var isRunning: Bool {
        return targetEndTime != nil && !isPaused
    }
    
    public var remainingSeconds: TimeInterval {
        if isPaused, let paused = pausedRemaining {
            return paused
        }
        guard let end = targetEndTime else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }
    
    /// Starts a timer for the given duration in seconds.
    public func startTimer(duration: TimeInterval) {
        cancelTimer()
        
        self.activeTimerDuration = duration
        self.targetEndTime = Date().addingTimeInterval(duration)
        self.isPaused = false
        self.pausedRemaining = nil
        
        // Immediate initial tick
        onTick?(duration, duration)
        
        // 1-second cadence for display refresh
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.countdownTimer = timer
    }
    
    public func pauseTimer() {
        guard isRunning else { return }
        pausedRemaining = remainingSeconds
        isPaused = true
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    public func resumeTimer() {
        guard isPaused, let remaining = pausedRemaining else { return }
        startTimer(duration: remaining)
    }
    
    public func cancelTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        targetEndTime = nil
        activeTimerDuration = nil
        isPaused = false
        pausedRemaining = nil
        onCancelled?()
    }
    
    private func handleTick() {
        guard let total = activeTimerDuration else { return }
        let rem = remainingSeconds
        
        if rem <= 0.05 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            targetEndTime = nil
            activeTimerDuration = nil
            onComplete?(total)
        } else {
            onTick?(rem, total)
        }
    }
    
    /// Formats remaining duration into MM:SS.
    public static func format(remaining: TimeInterval) -> String {
        let clamped = max(0, Int(remaining.rounded(.up)))
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
