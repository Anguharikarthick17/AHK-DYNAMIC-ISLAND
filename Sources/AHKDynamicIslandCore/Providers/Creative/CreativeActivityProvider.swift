import Foundation

/// Provider for creative design, 3D, and video editing suites adhering strictly to Section 20.
/// Only surfaces detailed activity when legitimate public signals exist.
/// Otherwise falls back gracefully to '<Application Name> • Active'.
public final class CreativeActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.creative"
    public let category: ActivityProviderCategory = .creative
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16 & 20)
    public let dataSourceDescription: String = "Legitimate public export/render hooks or distributed application signals."
    public let apiUsedDescription: String = "DistributedNotificationCenter / Public Foundation progress hooks."
    public let permissionsRequiredDescription: String = "None."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "When internal render engines do not expose public telemetry, truthfully falls back to '<App Name> • Active'. Never fakes percentage progress."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    private let lock = NSLock()
    private var activeCreativeTasks: [String: UniversalAppActivity] = [:]
    
    public init() {}
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        let bundle = application.bundleIdentifier.lowercased()
        let name = application.applicationName.lowercased()
        return bundle.contains("resolve") || bundle.contains("figma") || bundle.contains("blender") ||
               bundle.contains("photoshop") || bundle.contains("illustrator") || bundle.contains("premiere") ||
               name.contains("resolve") || name.contains("figma") || name.contains("blender")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        lock.lock()
        let active = activeCreativeTasks[application.bundleIdentifier]
        lock.unlock()
        
        if let active = active {
            return active
        }
        
        // Fallback per Section 20:
        // "DaVinci Resolve • Active", "Figma • Active"
        let glyph: String = {
            let lower = application.applicationName.lowercased()
            if lower.contains("figma") { return "◇" }
            if lower.contains("resolve") { return "◉" }
            return "✦"
        }()
        
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
            glyph: glyph
        )
    }
    
    /// Public hook for creative software or helper scripts to publish confirmed render/export progress.
    public func postCreativeActivity(
        bundleIdentifier: String,
        applicationName: String,
        title: String,
        subtitle: String? = nil,
        state: UniversalActivityState,
        progress: Double? = nil,
        isIndeterminate: Bool = false
    ) {
        let isTerminal = state.isTerminal
        let priority: ActivityPriority = isTerminal ? .activityCompletion : .appTask
        let glyph: String = {
            if isTerminal {
                return state == .completed ? "✓" : "⚠"
            }
            if state == .rendering { return "◉" }
            if state == .exporting { return "⇪" }
            return "✦"
        }()
        
        let activity = UniversalAppActivity(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            activityType: state == .rendering ? .rendering : (state == .exporting ? .exporting : .appActive),
            activityTitle: title,
            activitySubtitle: subtitle ?? state.rawValue.capitalized,
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
            activeCreativeTasks.removeValue(forKey: bundleIdentifier)
        } else {
            activeCreativeTasks[bundleIdentifier] = activity
        }
        lock.unlock()
        
        UniversalActivityRegistry.shared.registerActivity(activity)
        onActivityPublished?(activity)
    }
}
