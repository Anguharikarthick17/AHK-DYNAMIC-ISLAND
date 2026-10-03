import Foundation

/// Registry managing modular activity providers and multi-activity background state.
/// Adheres strictly to Section 9, 10, 11, 15, and 26.
public final class UniversalActivityRegistry: @unchecked Sendable {
    
    public static let shared = UniversalActivityRegistry()
    
    private let lock = NSLock()
    private var providers: [UniversalActivityProvider] = []
    private let genericFallbackProvider = GenericAppActivityProvider()
    
    // Active registered activities keyed by application bundle identifier
    private var registeredActivities: [String: UniversalAppActivity] = [:]
    
    public var onActivityRegistered: (@Sendable (UniversalAppActivity) -> Void)?
    public var onActivityUpdated: (@Sendable (UniversalAppActivity) -> Void)?
    public var onActivityRemoved: (@Sendable (String) -> Void)?
    
    public init() {
        // Register default modular providers in order of specificity
        register(provider: AHKEcosystemActivityProvider())
        register(provider: DevelopmentActivityProvider())
        register(provider: CreativeActivityProvider())
        register(provider: ChromeMediaActivityProvider())
        register(provider: MediaActivityProvider())
        register(provider: DownloadsActivityProvider())
        register(provider: SystemProgressActivityProvider())
    }
    
    // MARK: - Provider Registration
    
    /// Registers a modular activity provider.
    public func register(provider: UniversalActivityProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers.removeAll { $0.providerIdentifier == provider.providerIdentifier }
        providers.append(provider)
        
        provider.onActivityPublished = { [weak self] activity in
            self?.registerActivity(activity)
        }
    }
    
    /// Unregisters a provider by its identifier.
    public func unregister(providerIdentifier: String) {
        lock.lock()
        defer { lock.unlock() }
        if let index = providers.firstIndex(where: { $0.providerIdentifier == providerIdentifier }) {
            let provider = providers.remove(at: index)
            provider.stopObserving()
        }
    }
    
    /// Returns all currently registered providers.
    public var allProviders: [UniversalActivityProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers
    }
    
    // MARK: - Multi-Activity State Management
    
    /// Registers or replaces an active application activity in the background registry.
    public func registerActivity(_ activity: UniversalAppActivity) {
        lock.lock()
        registeredActivities[activity.bundleIdentifier] = activity
        lock.unlock()
        
        onActivityRegistered?(activity)
    }
    
    /// Mutates an existing active activity in-place.
    @discardableResult
    public func updateActivity(
        bundleIdentifier: String,
        mutating: (UniversalAppActivity) -> UniversalAppActivity
    ) -> UniversalAppActivity? {
        lock.lock()
        guard let existing = registeredActivities[bundleIdentifier] else {
            lock.unlock()
            return nil
        }
        let updated = mutating(existing)
        registeredActivities[bundleIdentifier] = updated
        lock.unlock()
        
        onActivityUpdated?(updated)
        return updated
    }
    
    /// Completes an activity, marking it completed or failed.
    @discardableResult
    public func completeActivity(
        bundleIdentifier: String,
        title: String? = nil,
        subtitle: String? = nil,
        succeeded: Bool = true
    ) -> UniversalAppActivity? {
        lock.lock()
        guard let existing = registeredActivities[bundleIdentifier] else {
            lock.unlock()
            return nil
        }
        let resolvedTitle = title ?? existing.applicationName
        let resolvedSubtitle = subtitle ?? (succeeded ? "Build Succeeded" : "Build Failed")
        let completed = UniversalAppActivity(
            applicationName: existing.applicationName,
            bundleIdentifier: existing.bundleIdentifier,
            activityType: succeeded ? .completed : .error,
            activityTitle: resolvedTitle,
            activitySubtitle: resolvedSubtitle,
            activityState: succeeded ? .completed : .failed,
            progress: succeeded ? 1.0 : nil,
            isIndeterminate: false,
            priority: .activityCompletion,
            confidence: existing.confidence,
            source: existing.source,
            startedAt: existing.startedAt,
            updatedAt: Date(),
            glyph: succeeded ? "✓" : "⚠",
            metadata: existing.metadata
        )
        registeredActivities[bundleIdentifier] = completed
        lock.unlock()
        
        onActivityUpdated?(completed)
        return completed
    }
    
    /// Removes an activity from the background registry (e.g. cancelled or expired).
    public func removeActivity(bundleIdentifier: String) {
        lock.lock()
        let removed = registeredActivities.removeValue(forKey: bundleIdentifier)
        lock.unlock()
        
        if removed != nil {
            onActivityRemoved?(bundleIdentifier)
        }
    }
    
    /// Clears all registered activities.
    public func clearAllActivities() {
        lock.lock()
        let keys = Array(registeredActivities.keys)
        registeredActivities.removeAll()
        lock.unlock()
        
        for key in keys {
            onActivityRemoved?(key)
        }
    }
    
    /// Returns all registered activities.
    public func allActivities() -> [UniversalAppActivity] {
        lock.lock()
        defer { lock.unlock() }
        return Array(registeredActivities.values)
    }
    
    /// Returns all active, ongoing (non-terminal) activities.
    public func activeOngoingActivities() -> [UniversalAppActivity] {
        lock.lock()
        defer { lock.unlock() }
        return registeredActivities.values.filter { $0.isOngoing }
    }
    
    /// Returns the single most relevant ongoing background activity according to the priority hierarchy:
    /// 1. Priority (highest first)
    /// 2. Confidence (high > medium > low)
    /// 3. Recency (most recently updated)
    public func topOngoingActivity() -> UniversalAppActivity? {
        lock.lock()
        let ongoing = registeredActivities.values.filter { $0.isOngoing }
        lock.unlock()
        
        return ongoing.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.updatedAt > rhs.updatedAt
        }.first
    }
    
    /// Returns the single top activity among all registered activities.
    public func topActivity() -> UniversalAppActivity? {
        lock.lock()
        let all = Array(registeredActivities.values)
        lock.unlock()
        
        return all.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.updatedAt > rhs.updatedAt
        }.first
    }
    
    // MARK: - Activity Resolution
    
    /// Resolves the most appropriate activity for any discovered application.
    /// Follows the resolution hierarchy:
    /// 1. Existing registered activity (if currently active/ongoing for this application)
    /// 2. Specialized providers (if matching and providing detailed telemetry)
    /// 3. Generic fallback provider (guaranteed generic identity for any Mac app)
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity {
        lock.lock()
        // If there is an existing ongoing activity registered for this app, return it
        if let existing = registeredActivities[application.bundleIdentifier], existing.isOngoing {
            lock.unlock()
            return existing
        }
        let currentProviders = providers
        lock.unlock()
        
        // Step 2: Check specialized modular providers
        for provider in currentProviders where provider.canHandle(application: application) {
            if let specializedActivity = provider.resolveActivity(for: application) {
                return specializedActivity
            }
        }
        
        // Step 3: Generic fallback provider (Confidence: LOW)
        if let fallback = genericFallbackProvider.resolveActivity(for: application) {
            return fallback
        }
        
        // Absolute fallback safety net
        return UniversalAppActivity(
            applicationName: application.applicationName,
            bundleIdentifier: application.bundleIdentifier,
            activityType: .appActive,
            activityTitle: application.applicationName,
            activitySubtitle: "Active",
            activityState: .active,
            priority: .appActive,
            confidence: .low,
            source: "DefaultFallback"
        )
    }
}
