import Foundation

/// Specialized provider for AHK ecosystem applications cooperating via the local AHK EventBus.
/// Adheres to Section 17 & 18: Zero surveillance, explicit cooperation, HIGH confidence.
public final class AHKEcosystemActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.ecosystem"
    public let category: ActivityProviderCategory = .ahk
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16)
    public let dataSourceDescription: String = "Explicit AHK EventBus messages and distributed notifications posted by cooperating AHK applications."
    public let apiUsedDescription: String = "AHKEventBus / DistributedNotificationCenter ('com.ahk.event.*')."
    public let permissionsRequiredDescription: String = "None. Inter-app local IPC within user session."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "Only receives telemetry when an AHK application explicitly posts an activity event."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    private let lock = NSLock()
    private var lastKnownEcosystemEvents: [String: AHKEcosystemEvent] = [:]
    
    public init() {
        startObserving()
    }
    
    public func startObserving() {
        AHKEventBus.shared.subscribe { [weak self] event in
            self?.recordEvent(event)
        }
    }
    
    public func recordEvent(_ event: AHKEcosystemEvent) {
        lock.lock()
        lastKnownEcosystemEvents[event.source.rawValue] = event
        lock.unlock()
        
        if let activity = createActivity(from: event) {
            onActivityPublished?(activity)
        }
    }
    
    public func clearEvent(for source: AHKAppSource) {
        lock.lock()
        lastKnownEcosystemEvents.removeValue(forKey: source.rawValue)
        lock.unlock()
    }
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        return application.bundleIdentifier.lowercased().hasPrefix("com.ahk.")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        lock.lock()
        let event = lastKnownEcosystemEvents[application.bundleIdentifier]
        lock.unlock()
        
        if let event = event, let act = createActivity(from: event) {
            return act
        }
        
        // Fallback for recognized AHK apps when no explicit event was recently posted
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
    
    private func createActivity(from event: AHKEcosystemEvent) -> UniversalAppActivity? {
        let action = event.payload["action"] ?? "update"
        let title = event.payload["title"] ?? event.payload["status"] ?? defaultAppName(for: event.source)
        let subtitle = event.payload["subtitle"] ?? (event.payload["status"])
        let stateStr = event.payload["state"] ?? "active"
        let state = UniversalActivityState(rawValue: stateStr) ?? .active
        let progress = event.payload["progress"].flatMap { Double($0) }
        let isIndet = event.payload["isIndeterminate"] == "true"
        let glyph = event.payload["icon"] ?? defaultGlyph(for: event.source)
        
        let actType: UniversalActivityType = {
            if action == "complete" || state == .completed { return .completed }
            if action == "fail" || state == .failed { return .error }
            return .appActive
        }()
        
        let priority: ActivityPriority = {
            if actType == .completed || actType == .error { return .activityCompletion }
            if let prioRaw = event.payload["priority"].flatMap({ Int($0) }),
               let parsed = ActivityPriority(rawValue: prioRaw) {
                return parsed
            }
            return .appProcessing
        }()
        
        return UniversalAppActivity(
            applicationName: defaultAppName(for: event.source),
            bundleIdentifier: event.source.rawValue,
            activityType: actType,
            activityTitle: title,
            activitySubtitle: subtitle,
            activityState: state,
            progress: progress,
            isIndeterminate: isIndet,
            priority: priority,
            confidence: .high,
            source: providerIdentifier,
            glyph: glyph,
            icon: glyph,
            metadata: event.payload
        )
    }
    
    private func defaultAppName(for source: AHKAppSource) -> String {
        switch source {
        case .ahkMini: return "AHK Mini"
        case .ahkKeyChain: return "AHK KeyChain"
        case .ahkDynamicIsland: return "AHK Dynamic Island"
        case .generic: return "AHK App"
        }
    }
    
    private func defaultGlyph(for source: AHKAppSource) -> String {
        switch source {
        case .ahkMini: return "🎮"
        case .ahkKeyChain: return "🔑"
        case .ahkDynamicIsland: return "✦"
        case .generic: return "✨"
        }
    }
}
