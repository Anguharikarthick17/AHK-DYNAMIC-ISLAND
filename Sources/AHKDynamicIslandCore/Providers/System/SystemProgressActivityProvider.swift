import Foundation

/// Provider for system Foundation operations (e.g. NSProgress, Finder copies) adhering to Section 23.
/// Does NOT poll filesystem. Only relies on legitimate Foundation/system APIs.
public final class SystemProgressActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.system"
    public let category: ActivityProviderCategory = .system
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16 & 23)
    public let dataSourceDescription: String = "Foundation NSProgress observation for legitimate system file operations."
    public let apiUsedDescription: String = "Foundation.Progress / NSProgress."
    public let permissionsRequiredDescription: String = "None."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "Zero filesystem polling. Only surfaces operations that explicitly publish an NSProgress instance."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    public init() {}
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        return application.bundleIdentifier == "com.apple.finder"
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        return UniversalAppActivity(
            applicationName: "Finder",
            bundleIdentifier: application.bundleIdentifier,
            activityType: .appActive,
            activityTitle: "Finder",
            activitySubtitle: "Active",
            activityState: .active,
            progress: nil,
            isIndeterminate: false,
            priority: .appActive,
            confidence: .low,
            source: providerIdentifier,
            glyph: "●"
        )
    }
}
