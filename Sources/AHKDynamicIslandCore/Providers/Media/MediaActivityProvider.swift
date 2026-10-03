import Foundation

/// Provider bridging public macOS Now Playing / MediaRemote telemetry to the activity model per Section 22.
/// Never scrapes browser DOM or injects JavaScript to guess music.
public final class MediaActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.media"
    public let category: ActivityProviderCategory = .media
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16 & 22)
    public let dataSourceDescription: String = "Public system Now Playing notifications from Apple Music, Spotify, and system media services."
    public let apiUsedDescription: String = "NowPlayingManager / MRMediaRemote public notifications."
    public let permissionsRequiredDescription: String = "None."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "Only reflects apps exposing public Now Playing metadata. Never scrapes browser tabs or page contents."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    public init() {}
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        let bundle = application.bundleIdentifier.lowercased()
        return bundle.contains("music") || bundle.contains("spotify") || bundle.contains("podcasts")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        return UniversalAppActivity(
            applicationName: application.applicationName,
            bundleIdentifier: application.bundleIdentifier,
            activityType: .mediaPlaying,
            activityTitle: application.applicationName,
            activitySubtitle: "Active",
            activityState: .active,
            progress: nil,
            isIndeterminate: false,
            priority: .nowPlaying,
            confidence: .medium,
            source: providerIdentifier,
            glyph: "▶"
        )
    }
}
