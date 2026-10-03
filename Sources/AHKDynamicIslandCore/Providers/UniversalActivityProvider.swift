import Foundation

/// Functional category for modular activity providers.
public enum ActivityProviderCategory: String, Sendable, CaseIterable {
    case system = "System"
    case media = "Media"
    case development = "Development"
    case creative = "Creative"
    case downloads = "Downloads"
    case ahk = "AHK"
    case generic = "Generic"
}

/// Modular contract for universal live activity providers adhering to Section 15 & Section 16.
public protocol UniversalActivityProvider: AnyObject, Sendable {
    var providerIdentifier: String { get }
    var category: ActivityProviderCategory { get }
    var isAvailable: Bool { get }
    
    // Privacy and API transparency documentation (Section 16)
    var dataSourceDescription: String { get }
    var apiUsedDescription: String { get }
    var permissionsRequiredDescription: String { get }
    var confidence: ActivityConfidence { get }
    var limitationsDescription: String { get }
    
    /// Whether this provider supports or manages telemetry for the discovered application.
    func canHandle(application: DiscoveredApplication) -> Bool
    
    /// Synchronously resolves an activity when an application is discovered or focused.
    func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity?
    
    /// Starts asynchronous event observation if supported.
    func startObserving()
    
    /// Stops asynchronous event observation to preserve battery and near-zero idle CPU.
    func stopObserving()
    
    /// Callback when the provider publishes an activity update asynchronously.
    var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)? { get set }
}

public extension UniversalActivityProvider {
    func startObserving() {}
    func stopObserving() {}
}
