import Foundation

/// Public SDK allowing any current or future AHK ecosystem app to publish activities to the Dynamic Island.
/// Adheres strictly to Section 17 & Section 18 for seamless future application onboarding.
public struct AHKActivity {
    
    /// Starts a live activity for an AHK application.
    @discardableResult
    public static func start(
        app: AHKAppSource,
        title: String,
        subtitle: String? = nil,
        state: UniversalActivityState = .active,
        progress: Double? = nil,
        isIndeterminate: Bool = false,
        priority: ActivityPriority = .appProcessing,
        icon: String? = nil,
        metadata: [String: String] = [:]
    ) -> UniversalAppActivity {
        var payload = metadata
        payload["action"] = "start"
        payload["title"] = title
        if let sub = subtitle { payload["subtitle"] = sub }
        payload["state"] = state.rawValue
        if let p = progress { payload["progress"] = String(p) }
        payload["isIndeterminate"] = isIndeterminate ? "true" : "false"
        payload["priority"] = String(priority.rawValue)
        if let icon = icon { payload["icon"] = icon }
        
        let event = AHKEcosystemEvent(source: app, name: "activity", payload: payload)
        AHKEventBus.shared.post(event)
        
        let appName = resolveAppName(for: app, metadata: metadata)
        let activity = UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: app.rawValue,
            activityType: .appActive,
            activityTitle: title,
            activitySubtitle: subtitle,
            activityState: state,
            progress: progress,
            isIndeterminate: isIndeterminate,
            priority: priority,
            confidence: .high,
            source: "AHKActivitySDK",
            glyph: icon,
            icon: icon,
            metadata: payload
        )
        UniversalActivityRegistry.shared.registerActivity(activity)
        return activity
    }
    
    /// Updates an existing ongoing live activity.
    @discardableResult
    public static func update(
        app: AHKAppSource,
        title: String? = nil,
        subtitle: String? = nil,
        state: UniversalActivityState? = nil,
        progress: Double? = nil,
        isIndeterminate: Bool? = nil,
        metadata: [String: String] = [:]
    ) -> UniversalAppActivity? {
        var payload = metadata
        payload["action"] = "update"
        if let title = title { payload["title"] = title }
        if let subtitle = subtitle { payload["subtitle"] = subtitle }
        if let state = state { payload["state"] = state.rawValue }
        if let progress = progress { payload["progress"] = String(progress) }
        if let indet = isIndeterminate { payload["isIndeterminate"] = indet ? "true" : "false" }
        
        let event = AHKEcosystemEvent(source: app, name: "activity", payload: payload)
        AHKEventBus.shared.post(event)
        
        return UniversalActivityRegistry.shared.updateActivity(bundleIdentifier: app.rawValue, mutating: { act in
            let newTitle = title ?? act.activityTitle
            let newSub = subtitle ?? act.activitySubtitle
            let newState = state ?? act.activityState
            let newProg = progress ?? act.progress
            let newIndet = isIndeterminate ?? act.isIndeterminate
            return UniversalAppActivity(
                applicationName: act.applicationName,
                bundleIdentifier: act.bundleIdentifier,
                activityType: act.activityType,
                activityTitle: newTitle,
                activitySubtitle: newSub,
                activityState: newState,
                progress: newProg,
                isIndeterminate: newIndet,
                priority: act.priority,
                confidence: act.confidence,
                source: act.source,
                startedAt: act.startedAt,
                updatedAt: Date(),
                estimatedCompletion: act.estimatedCompletion,
                glyph: act.glyph,
                icon: act.icon,
                metadata: act.metadata.merging(payload) { _, new in new }
            )
        })
    }
    
    /// Completes an activity, triggering a transient success presentation.
    @discardableResult
    public static func complete(
        app: AHKAppSource,
        title: String? = nil,
        subtitle: String? = "Completed",
        metadata: [String: String] = [:]
    ) -> UniversalAppActivity {
        var payload = metadata
        payload["action"] = "complete"
        payload["state"] = UniversalActivityState.completed.rawValue
        if let title = title { payload["title"] = title }
        if let subtitle = subtitle { payload["subtitle"] = subtitle }
        
        let event = AHKEcosystemEvent(source: app, name: "activity", payload: payload)
        AHKEventBus.shared.post(event)
        
        let appName = resolveAppName(for: app, metadata: metadata)
        let resolvedTitle = title ?? appName
        let activity = UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: app.rawValue,
            activityType: .completed,
            activityTitle: resolvedTitle,
            activitySubtitle: subtitle ?? "Completed",
            activityState: .completed,
            progress: 1.0,
            isIndeterminate: false,
            priority: .activityCompletion,
            confidence: .high,
            source: "AHKActivitySDK",
            glyph: "✓",
            metadata: payload
        )
        UniversalActivityRegistry.shared.registerActivity(activity)
        return activity
    }
    
    /// Signals that an activity failed.
    @discardableResult
    public static func fail(
        app: AHKAppSource,
        title: String? = nil,
        subtitle: String? = "Failed",
        error: String? = nil,
        metadata: [String: String] = [:]
    ) -> UniversalAppActivity {
        var payload = metadata
        payload["action"] = "fail"
        payload["state"] = UniversalActivityState.failed.rawValue
        if let title = title { payload["title"] = title }
        if let subtitle = subtitle { payload["subtitle"] = subtitle }
        if let err = error { payload["error"] = err }
        
        let event = AHKEcosystemEvent(source: app, name: "activity", payload: payload)
        AHKEventBus.shared.post(event)
        
        let appName = resolveAppName(for: app, metadata: metadata)
        let resolvedTitle = title ?? appName
        let activity = UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: app.rawValue,
            activityType: .error,
            activityTitle: resolvedTitle,
            activitySubtitle: subtitle ?? "Failed",
            activityState: .failed,
            progress: nil,
            isIndeterminate: false,
            priority: .activityCompletion,
            confidence: .high,
            source: "AHKActivitySDK",
            glyph: "⚠",
            metadata: payload
        )
        UniversalActivityRegistry.shared.registerActivity(activity)
        return activity
    }
    
    /// Cancels an activity and removes it from the active registry.
    public static func cancel(
        app: AHKAppSource,
        title: String? = nil,
        metadata: [String: String] = [:]
    ) {
        var payload = metadata
        payload["action"] = "cancel"
        payload["state"] = UniversalActivityState.cancelled.rawValue
        if let title = title { payload["title"] = title }
        
        let event = AHKEcosystemEvent(source: app, name: "activity", payload: payload)
        AHKEventBus.shared.post(event)
        
        UniversalActivityRegistry.shared.removeActivity(bundleIdentifier: app.rawValue)
    }
    
    private static func resolveAppName(for app: AHKAppSource, metadata: [String: String]) -> String {
        if let name = metadata["appName"], !name.isEmpty {
            return name
        }
        switch app {
        case .ahkMini:
            return "AHK Mini"
        case .ahkKeyChain:
            return "AHK KeyChain"
        case .ahkDynamicIsland:
            return "AHK Dynamic Island"
        case .generic:
            return metadata["appName"] ?? "AHK App"
        }
    }
}
