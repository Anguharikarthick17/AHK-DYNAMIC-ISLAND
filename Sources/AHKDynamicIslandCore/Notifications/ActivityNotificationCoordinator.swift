import Foundation

/// Coordinates system and AHK internal activity notifications using public APIs.
@MainActor
public final class ActivityNotificationCoordinator {
    
    public var onNotificationPosted: ((String, String?, String?) -> Void)?
    
    public init() {}
    
    /// Posts a public activity notification into the dynamic island.
    public func postNotification(title: String, subtitle: String? = nil, iconName: String? = "bell.fill") {
        onNotificationPosted?(title, subtitle, iconName)
    }
}
