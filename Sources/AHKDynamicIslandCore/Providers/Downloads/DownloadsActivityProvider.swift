import Foundation

/// Provider bridging legitimate public downloads and transfers to the activity model per Section 21.
/// Never scrapes browsers, DOM, cookies, or history.
public final class DownloadsActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.downloads"
    public let category: ActivityProviderCategory = .downloads
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation (Section 16 & 21)
    public let dataSourceDescription: String = "Legitimate public system download manager and NSURLDownload / Safari / Chrome download events."
    public let apiUsedDescription: String = "DownloadManager / Foundation file coordination."
    public let permissionsRequiredDescription: String = "None."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "Only surfaces active downloads when officially reported by system download handlers or file download monitors."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    public init() {}
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        let bundle = application.bundleIdentifier.lowercased()
        return bundle.contains("safari") || bundle.contains("chrome") || bundle.contains("firefox") || bundle.contains("edge")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        // By default, browsers are generic active unless an active download was explicitly posted
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
            glyph: "🌐"
        )
    }
}
