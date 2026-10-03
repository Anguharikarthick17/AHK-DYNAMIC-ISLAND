import Foundation

/// Provider for development environments and compilers adhering strictly to Section 19.
/// Uses ONLY legitimate public signals (DistributedNotificationCenter, build tool notifications).
/// NEVER inspects Xcode memory, scrapes Xcode UI, or uses Accessibility for activity inference.
public final class DevelopmentActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.development"
    public let category: ActivityProviderCategory = .development
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16 & 19)
    public let dataSourceDescription: String = "macOS DistributedNotificationCenter signals from Xcode build services and development toolchains."
    public let apiUsedDescription: String = "DistributedNotificationCenter.default() observing 'com.apple.dt.Xcode.*' and developer build events."
    public let permissionsRequiredDescription: String = "None. Standard macOS user space distributed notifications."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "Does not inspect Xcode process memory or scrape UI. When no build notification is active, truthfully falls back to 'Xcode • Active'."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    private let lock = NSLock()
    private var activeBuilds: [String: UniversalAppActivity] = [:]
    
    public init() {
        startObserving()
    }
    
    public func startObserving() {
        // Observe public Apple developer notifications where broadcasted
        let center = DistributedNotificationCenter.default()
        
        center.addObserver(
            forName: NSNotification.Name("com.apple.dt.Xcode.BuildStarted"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            self?.handleXcodeBuildStarted(notif)
        }
        
        center.addObserver(
            forName: NSNotification.Name("com.apple.dt.Xcode.BuildSucceeded"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            self?.handleXcodeBuildCompleted(notif, succeeded: true)
        }
        
        center.addObserver(
            forName: NSNotification.Name("com.apple.dt.Xcode.BuildFailed"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            self?.handleXcodeBuildCompleted(notif, succeeded: false)
        }
    }
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        let bundle = application.bundleIdentifier.lowercased()
        let name = application.applicationName.lowercased()
        return bundle.contains("xcode") || bundle.contains("cursor") || bundle.contains("antigravity") ||
               bundle.contains("code") || bundle.contains("intellij") || name.contains("xcode")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        lock.lock()
        let active = activeBuilds[application.bundleIdentifier]
        lock.unlock()
        
        if let active = active {
            return active
        }
        
        // Truthful generic fallback per Section 19:
        // "If reliable public activity information is unavailable: fall back to: Xcode • Active"
        return UniversalAppActivity(
            applicationName: application.applicationName,
            bundleIdentifier: application.bundleIdentifier,
            activityType: .appActive,
            activityTitle: application.applicationName,
            activitySubtitle: "Active",
            activityState: .active,
            progress: nil,
            isIndeterminate: false,
            priority: .appActive,
            confidence: .low,
            source: providerIdentifier,
            glyph: "⚒"
        )
    }
    
    /// Public API for development build tools / scripts to report legitimate build progress
    public func postDevelopmentActivity(
        bundleIdentifier: String = "com.apple.dt.Xcode",
        applicationName: String = "Xcode",
        title: String,
        subtitle: String? = nil,
        state: UniversalActivityState,
        progress: Double? = nil,
        isIndeterminate: Bool = false
    ) {
        let isTerminal = state.isTerminal
        let priority: ActivityPriority = isTerminal ? .activityCompletion : .appTask
        let glyph: String = {
            switch state {
            case .completed: return "✓"
            case .failed: return "⚠"
            default: return "🔨"
            }
        }()
        
        let activity = UniversalAppActivity(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            activityType: isTerminal ? (state == .completed ? .completed : .error) : .building,
            activityTitle: title,
            activitySubtitle: subtitle ?? (isTerminal ? (state == .completed ? "Build Succeeded" : "Build Failed") : "Building"),
            activityState: state,
            progress: progress,
            isIndeterminate: isIndeterminate,
            priority: priority,
            confidence: .high,
            source: providerIdentifier,
            glyph: glyph,
            icon: glyph
        )
        
        lock.lock()
        if isTerminal {
            activeBuilds.removeValue(forKey: bundleIdentifier)
        } else {
            activeBuilds[bundleIdentifier] = activity
        }
        lock.unlock()
        
        UniversalActivityRegistry.shared.registerActivity(activity)
        onActivityPublished?(activity)
    }
    
    private func handleXcodeBuildStarted(_ notif: Notification) {
        let scheme = (notif.userInfo?["scheme"] as? String) ?? "MyApp"
        postDevelopmentActivity(
            bundleIdentifier: "com.apple.dt.Xcode",
            applicationName: "Xcode",
            title: "Building \(scheme)",
            subtitle: "Building...",
            state: .building,
            progress: nil,
            isIndeterminate: true
        )
    }
    
    private func handleXcodeBuildCompleted(_ notif: Notification, succeeded: Bool) {
        postDevelopmentActivity(
            bundleIdentifier: "com.apple.dt.Xcode",
            applicationName: "Xcode",
            title: "Xcode",
            subtitle: succeeded ? "Build Succeeded" : "Build Failed",
            state: succeeded ? .completed : .failed,
            progress: succeeded ? 1.0 : nil,
            isIndeterminate: false
        )
    }
}
