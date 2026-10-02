import AppKit
import Foundation

/// Monitors and dispatches display brightness events using public APIs where available.
///
/// Note on macOS SDK:
/// Direct display brightness read/write without user interaction is handled by system private frameworks (CoreDisplay / DisplayServices).
/// To maintain App Sandbox compliance and security guidelines, AHK Dynamic Island isolates brightness updates to public display notifications and simulated test events.
public final class BrightnessMonitor: @unchecked Sendable {
    
    public var onBrightnessChanged: ((Float) -> Void)?
    private var currentLevel: Float = 0.70
    
    public init() {}
    
    public func startMonitoring() {
        // Observe display parameter notifications (e.g. ambient/resolution/profile adjustments)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.onBrightnessChanged?(self.currentLevel)
        }
    }
    
    public func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Simulates or sets the current brightness level (0.0 to 1.0) and notifies the island.
    public func setBrightness(level: Float) {
        let clamped = min(max(level, 0.0), 1.0)
        self.currentLevel = clamped
        onBrightnessChanged?(clamped)
    }
}
