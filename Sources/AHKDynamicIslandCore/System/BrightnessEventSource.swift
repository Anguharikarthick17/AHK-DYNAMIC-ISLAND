import AppKit
import Foundation

/// Protocol defining brightness monitoring capability.
public protocol BrightnessEventSource: AnyObject, Sendable {
    var onBrightnessChanged: (@Sendable (Float) -> Void)? { get set }
    func start()
    func stop()
}

/// Legitimate public brightness event source.
///
/// NOTE ON MACOS HARDWARE BRIGHTNESS:
/// Public AppKit and CoreGraphics APIs on macOS do not expose internal display
/// backlight luminance or brightness keystroke events to non-privileged/sandboxed apps.
/// Private DisplayServices.framework (e.g. `DisplayServicesGetBrightness`) is deliberately
/// avoided to protect user privacy and system stability.
///
/// This implementation listens to public screen configuration notifications (`didChangeScreenParametersNotification`)
/// and exposes a clean, uncompromised interface ready for legitimate future OS-level brightness events.
public final class PublicBrightnessEventSource: BrightnessEventSource, @unchecked Sendable {
    
    /// Explicit architectural declaration of hardware detection capability via public APIs.
    public static let isHardwareBrightnessSupported: Bool = false
    
    public var onBrightnessChanged: (@Sendable (Float) -> Void)?
    
    private var isListening: Bool = false
    private var observer: NSObjectProtocol?
    
    public init() {}
    
    deinit {
        stop()
    }
    
    public func start() {
        guard !isListening else { return }
        isListening = true
        
        // Observe public display configuration changes
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // When screen parameters change, emit nominal baseline if handler installed
            self?.onBrightnessChanged?(0.75)
        }
    }
    
    public func stop() {
        guard isListening else { return }
        isListening = false
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            self.observer = nil
        }
    }
    
    /// Test injection hook for unit tests only.
    public func injectTestBrightness(level: Float) {
        onBrightnessChanged?(min(max(level, 0.0), 1.0))
    }
}
