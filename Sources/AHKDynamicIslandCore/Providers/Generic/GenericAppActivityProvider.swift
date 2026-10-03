import Foundation

/// Universal fallback provider that guarantees generic recognition for ANY Mac application without hardcoding.
/// Adheres strictly to Section 6: Accuracy is more important than visual richness.
public final class GenericAppActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.generic"
    public let category: ActivityProviderCategory = .generic
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16)
    public let dataSourceDescription: String = "Public NSWorkspace application activation and running application metadata."
    public let apiUsedDescription: String = "NSWorkspace.shared.frontmostApplication / didActivateApplicationNotification."
    public let permissionsRequiredDescription: String = "None. Standard macOS user space."
    public let confidence: ActivityConfidence = .low
    public let limitationsDescription: String = "Does not inspect private process state. Truthfully presents generic active identity (<App Name> • Active)."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    public init() {}
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        return !application.applicationName.isEmpty
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
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
            metadata: ["pid": "\(application.processIdentifier)"]
        )
    }
}
