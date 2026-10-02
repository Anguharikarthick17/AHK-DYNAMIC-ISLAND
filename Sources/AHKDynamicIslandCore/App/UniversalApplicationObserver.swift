import AppKit
import Foundation

/// Purely event-driven observer monitoring macOS application lifecycle events without polling.
/// Discovers applications dynamically and resolves universal activity via the registry.
@MainActor
public final class UniversalApplicationObserver: NSObject {
    
    public var onApplicationActivityDetected: ((UniversalAppActivity) -> Void)?
    public var onApplicationDeactivated: ((DiscoveredApplication) -> Void)?
    public var onApplicationTerminated: ((DiscoveredApplication) -> Void)?
    
    public private(set) var currentFrontmostApp: DiscoveredApplication?
    public private(set) var isObserving: Bool = false
    
    public let registry: UniversalActivityRegistry
    private let selfBundleID: String
    
    public init(
        registry: UniversalActivityRegistry = UniversalActivityRegistry.shared,
        selfBundleID: String = Bundle.main.bundleIdentifier ?? "com.ahk.dynamicisland"
    ) {
        self.registry = registry
        self.selfBundleID = selfBundleID
        super.init()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    /// Starts event-driven observation of macOS application notifications.
    public func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        let center = NSWorkspace.shared.notificationCenter
        
        // 1. Application activation (user switches to an app)
        center.addObserver(
            self,
            selector: #selector(handleApplicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // 2. Application deactivation
        center.addObserver(
            self,
            selector: #selector(handleApplicationDeactivated(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
        
        // 3. Application termination
        center.addObserver(
            self,
            selector: #selector(handleApplicationTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // 4. Application launch
        center.addObserver(
            self,
            selector: #selector(handleApplicationLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        // Inspect initial frontmost application
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            let discovered = makeDiscoveredApp(from: frontmost, isActive: true)
            if isValidExternalApp(discovered) {
                self.currentFrontmostApp = discovered
            }
        }
    }
    
    /// Stops observing lifecycle events.
    public func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleApplicationActivated(_ notification: Notification) {
        guard let runningApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let discovered = makeDiscoveredApp(from: runningApp, isActive: true)
        guard isValidExternalApp(discovered) else { return }
        
        self.currentFrontmostApp = discovered
        let activity = registry.resolveActivity(for: discovered)
        onApplicationActivityDetected?(activity)
    }
    
    @objc private func handleApplicationDeactivated(_ notification: Notification) {
        guard let runningApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let discovered = makeDiscoveredApp(from: runningApp, isActive: false)
        guard isValidExternalApp(discovered) else { return }
        
        if currentFrontmostApp?.bundleIdentifier == discovered.bundleIdentifier {
            currentFrontmostApp = nil
        }
        onApplicationDeactivated?(discovered)
    }
    
    @objc private func handleApplicationTerminated(_ notification: Notification) {
        guard let runningApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let discovered = makeDiscoveredApp(from: runningApp, isActive: false)
        guard isValidExternalApp(discovered) else { return }
        
        if currentFrontmostApp?.bundleIdentifier == discovered.bundleIdentifier {
            currentFrontmostApp = nil
        }
        onApplicationTerminated?(discovered)
    }
    
    @objc private func handleApplicationLaunched(_ notification: Notification) {
        // App launched in background or foreground; activation will handle if it becomes active
    }
    
    // MARK: - Helpers
    
    private func makeDiscoveredApp(from runningApp: NSRunningApplication, isActive: Bool) -> DiscoveredApplication {
        let name = runningApp.localizedName ?? runningApp.bundleIdentifier ?? "Application"
        let bundleID = runningApp.bundleIdentifier ?? "com.unknown.\(name.lowercased().replacingOccurrences(of: " ", with: ""))"
        let pid = runningApp.processIdentifier
        let launchDate = runningApp.launchDate
        
        return DiscoveredApplication(
            applicationName: name,
            bundleIdentifier: bundleID,
            processIdentifier: pid,
            isActive: isActive,
            launchDate: launchDate
        )
    }
    
    private func isValidExternalApp(_ discovered: DiscoveredApplication) -> Bool {
        // Exclude self (dynamic island)
        if discovered.bundleIdentifier == selfBundleID {
            return false
        }
        // Exclude system background daemons with no name
        if discovered.applicationName.isEmpty {
            return false
        }
        return true
    }
}
