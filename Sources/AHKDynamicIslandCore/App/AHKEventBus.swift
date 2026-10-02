import Foundation

/// Ecosystem event identifiers for AHK internal applications.
public enum AHKAppSource: String, Sendable {
    case ahkMini = "com.ahk.mini"
    case ahkKeyChain = "com.ahk.keychain"
    case ahkDynamicIsland = "com.ahk.dynamicisland"
    case generic = "com.ahk.app"
}

/// Generic payload for inter-app AHK events.
public struct AHKEcosystemEvent: Sendable {
    public let source: AHKAppSource
    public let name: String
    public let payload: [String: String]
    public let timestamp: Date
    
    public init(source: AHKAppSource, name: String, payload: [String: String] = [:], timestamp: Date = Date()) {
        self.source = source
        self.name = name
        self.payload = payload
        self.timestamp = timestamp
    }
}

/// Internal local event bus for the AHK ecosystem.
/// Coordinates in-process and local inter-process events without external networking.
public final class AHKEventBus: @unchecked Sendable {
    
    public static let shared = AHKEventBus()
    
    private let lock = NSLock()
    private var localSubscribers: [(AHKEcosystemEvent) -> Void] = []
    
    public init() {
        setupDistributedObserver()
    }
    
    /// Publishes an ecosystem event locally and across local processes.
    public func post(_ event: AHKEcosystemEvent) {
        lock.lock()
        let subscribers = localSubscribers
        lock.unlock()
        
        for subscriber in subscribers {
            subscriber(event)
        }
        
        // Broadcast across local distributed notifications
        let notificationName = NSNotification.Name("com.ahk.event.\(event.name)")
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: event.source.rawValue,
            userInfo: event.payload,
            deliverImmediately: true
        )
    }
    
    /// Subscribes to in-process AHK ecosystem events.
    public func subscribe(handler: @escaping @Sendable (AHKEcosystemEvent) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        localSubscribers.append(handler)
    }
    
    private func setupDistributedObserver() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.ahk.event.activity"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let sourceStr = (notification.object as? String) ?? AHKAppSource.generic.rawValue
            let source = AHKAppSource(rawValue: sourceStr) ?? .generic
            let payload = (notification.userInfo as? [String: String]) ?? [:]
            let event = AHKEcosystemEvent(source: source, name: "activity", payload: payload)
            self?.postLocalOnly(event)
        }
    }
    
    private func postLocalOnly(_ event: AHKEcosystemEvent) {
        lock.lock()
        let subscribers = localSubscribers
        lock.unlock()
        for subscriber in subscribers {
            subscriber(event)
        }
    }
}
