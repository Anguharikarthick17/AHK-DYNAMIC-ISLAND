import AppKit
import Foundation

/// Monitors and dispatches display brightness events using public APIs where available.
/// Conforms to BrightnessEventSource with explicit architectural boundary reporting.
public final class BrightnessMonitor: BrightnessEventSource, @unchecked Sendable {
    
    public var onBrightnessChanged: (@Sendable (Float) -> Void)? {
        get { eventSource.onBrightnessChanged }
        set { eventSource.onBrightnessChanged = newValue }
    }
    
    private let eventSource: PublicBrightnessEventSource
    private var currentLevel: Float = 0.70
    
    public init(eventSource: PublicBrightnessEventSource = PublicBrightnessEventSource()) {
        self.eventSource = eventSource
    }
    
    public func start() {
        eventSource.start()
    }
    
    public func stop() {
        eventSource.stop()
    }
    
    public func startMonitoring() {
        start()
    }
    
    public func stopMonitoring() {
        stop()
    }
    
    /// Test or future programmatic brightness update handler.
    public func setBrightness(level: Float) {
        let clamped = min(max(level, 0.0), 1.0)
        self.currentLevel = clamped
        eventSource.injectTestBrightness(level: clamped)
    }
}
