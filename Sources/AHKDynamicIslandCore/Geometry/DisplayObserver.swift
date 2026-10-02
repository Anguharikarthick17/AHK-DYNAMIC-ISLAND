import AppKit
import Foundation

/// Observes screen parameter changes, display connection/disconnection, and resolution scaling.
@MainActor
public final class DisplayObserver {
    
    public typealias ChangeHandler = @MainActor () -> Void
    
    private var changeHandler: ChangeHandler?
    private var observers: [NSObjectProtocol] = []
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval
    
    public init(debounceInterval: TimeInterval = 0.15) {
        self.debounceInterval = debounceInterval
    }
    
    isolated deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        debounceTask?.cancel()
    }
    
    /// Starts observing system display configuration changes.
    public func startObserving(onChange: @escaping ChangeHandler) {
        self.changeHandler = onChange
        stopObserving()
        
        // Listen to screen parameter changes (resolution, scaling, count)
        let screenParamObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleNotification()
            }
        }
        observers.append(screenParamObserver)
        
        // Listen to colorSpaceDidChangeNotification (display reconfiguration)
        let screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSScreen.colorSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleNotification()
            }
        }
        observers.append(screenChangeObserver)
    }
    
    /// Stops observing.
    public func stopObserving() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        debounceTask?.cancel()
        debounceTask = nil
    }
    
    private func handleNotification() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let nanoseconds = UInt64(self.debounceInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self.changeHandler?()
        }
    }
    
    /// Manually triggers the display change handler (useful for testing or forced layout updates).
    public func triggerManualUpdate() {
        debounceTask?.cancel()
        changeHandler?()
    }
}
