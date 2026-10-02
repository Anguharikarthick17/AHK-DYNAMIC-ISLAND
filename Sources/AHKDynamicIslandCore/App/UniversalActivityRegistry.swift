import Foundation

/// Protocol for activity providers contributing application telemetry to the Dynamic Island.
public protocol UniversalActivityProvider: Sendable {
    var providerIdentifier: String { get }
    func canHandle(application: DiscoveredApplication) -> Bool
    func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity?
}

/// Fallback provider that guarantees generic recognition for ANY Mac application without hardcoding.
public final class GenericAppActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.generic"
    
    public init() {}
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        // Can handle any valid Mac application
        return !application.applicationName.isEmpty
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        return UniversalAppActivity(
            applicationName: application.applicationName,
            bundleIdentifier: application.bundleIdentifier,
            activityType: .appActive,
            stateText: "Active",
            priority: .appActive,
            timestamp: Date(),
            metadata: ["pid": "\(application.processIdentifier)"],
            confidence: .low,
            source: providerIdentifier
        )
    }
}

/// Specialized provider for AHK ecosystem applications cooperating via the local AHK EventBus.
public final class AHKEcosystemActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.ecosystem"
    
    private let lock = NSLock()
    private var lastKnownEcosystemEvents: [String: AHKEcosystemEvent] = [:]
    
    public init() {}
    
    public func recordEvent(_ event: AHKEcosystemEvent) {
        lock.lock()
        defer { lock.unlock() }
        lastKnownEcosystemEvents[event.source.rawValue] = event
    }
    
    public func clearEvent(for source: AHKAppSource) {
        lock.lock()
        defer { lock.unlock() }
        lastKnownEcosystemEvents.removeValue(forKey: source.rawValue)
    }
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        return application.bundleIdentifier.lowercased().hasPrefix("com.ahk.")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        lock.lock()
        let event = lastKnownEcosystemEvents[application.bundleIdentifier]
        lock.unlock()
        
        if application.bundleIdentifier == AHKAppSource.ahkMini.rawValue {
            let state = event?.payload["status"] ?? "Playing"
            return UniversalAppActivity(
                applicationName: "AHK Mini",
                bundleIdentifier: application.bundleIdentifier,
                activityType: .appActive,
                stateText: state,
                priority: .appProcessing,
                timestamp: Date(),
                metadata: event?.payload ?? [:],
                confidence: .high,
                source: providerIdentifier,
                glyph: "🎮"
            )
        }
        
        if application.bundleIdentifier == AHKAppSource.ahkKeyChain.rawValue {
            let state = event?.payload["status"] ?? "Unlocked"
            return UniversalAppActivity(
                applicationName: "AHK KeyChain",
                bundleIdentifier: application.bundleIdentifier,
                activityType: .appActive,
                stateText: state,
                priority: .appProcessing,
                timestamp: Date(),
                metadata: event?.payload ?? [:],
                confidence: .high,
                source: providerIdentifier,
                glyph: "🔑"
            )
        }
        
        return nil
    }
}

/// Registry managing generic fallback and optional specialized activity providers.
public final class UniversalActivityRegistry: @unchecked Sendable {
    
    public static let shared = UniversalActivityRegistry()
    
    private let lock = NSLock()
    private var specializedProviders: [UniversalActivityProvider] = []
    private let genericFallbackProvider = GenericAppActivityProvider()
    
    public init() {
        // Register default ecosystem provider
        register(provider: AHKEcosystemActivityProvider())
    }
    
    /// Registers an optional specialized provider (e.g. for AHK apps, developer tools, or media).
    public func register(provider: UniversalActivityProvider) {
        lock.lock()
        defer { lock.unlock() }
        specializedProviders.removeAll { $0.providerIdentifier == provider.providerIdentifier }
        specializedProviders.append(provider)
    }
    
    /// Resolves the most appropriate activity for any discovered application.
    /// Follows the resolution hierarchy:
    /// 1. Specialized providers (if matching and providing detailed telemetry)
    /// 2. Generic fallback provider (guaranteed generic identity for any Mac app)
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity {
        lock.lock()
        let providers = specializedProviders
        lock.unlock()
        
        // Step 1 & 2: Check specialized providers
        for provider in providers where provider.canHandle(application: application) {
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
            stateText: "Active",
            priority: .appActive,
            confidence: .low,
            source: "DefaultFallback"
        )
    }
}
