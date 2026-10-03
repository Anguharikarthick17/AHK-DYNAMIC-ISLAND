import Foundation

/// Bridge receiving, validating, and coalescing Chrome Native Messaging media messages.
/// Adheres strictly to Section 6, 18, 19, and 21 (coalescing, no polling, stale event protection).
public final class ChromeNativeMessagingBridge: @unchecked Sendable {
    
    public static let shared = ChromeNativeMessagingBridge()
    public static let notificationName = NSNotification.Name("com.ahk.dynamicisland.chrome.media")
    
    private let lock = NSLock()
    private var isObserving: Bool = false
    
    // Session state tracking
    private var activeSessionId: String?
    private var lastEventTimestamp: Double = 0
    private var lastProgressEmittedTime: Date = .distantPast
    private var lastEmittedPosition: Double = -1
    
    public var onMessageReceived: (@Sendable (ChromeMediaMessage) -> Void)?
    
    public init() {
        startObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    /// Starts observing distributed notifications from the native messaging host.
    public func startObserving() {
        lock.lock()
        guard !isObserving else {
            lock.unlock()
            return
        }
        isObserving = true
        lock.unlock()
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDistributedNotification(_:)),
            name: Self.notificationName,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }
    
    /// Stops observing to ensure zero CPU wakeups when idle.
    public func stopObserving() {
        lock.lock()
        guard isObserving else {
            lock.unlock()
            return
        }
        isObserving = false
        lock.unlock()
        
        DistributedNotificationCenter.default().removeObserver(self, name: Self.notificationName, object: nil)
    }
    
    @objc private func handleDistributedNotification(_ notification: Notification) {
        guard let jsonString = notification.userInfo?["payload"] as? String,
              let data = jsonString.data(using: .utf8),
              let message = ChromeMediaMessage.decode(from: data) else {
            return
        }
        
        processIncomingMessage(message)
    }
    
    /// Processes and validates an incoming Chrome media message.
    /// Rejects malformed, unauthorized, or stale events.
    public func processIncomingMessage(_ message: ChromeMediaMessage) {
        guard message.isValid else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        let msgTime = message.timestamp ?? Date().timeIntervalSince1970
        let incomingSessionId = message.sessionId ?? "default"
        
        // Stale event rejection (Section 21)
        if let currentSession = activeSessionId, currentSession == incomingSessionId {
            if msgTime < lastEventTimestamp {
                // Reject older event received out of order
                return
            }
        }
        
        // Progress update coalescing (Section 6 & 19)
        if message.event == .timeupdate {
            let now = Date()
            let timeSinceLast = now.timeIntervalSince(lastProgressEmittedTime)
            
            // Check if user sought (large jump in position >= 3.0 seconds)
            let isSeek: Bool = {
                if let pos = message.position, lastEmittedPosition >= 0 {
                    return abs(pos - lastEmittedPosition) >= 3.0
                }
                return false
            }()
            
            // Coalesce updates to at most once per 1.5 seconds unless seek occurred
            if !isSeek && timeSinceLast < 1.5 {
                return
            }
            
            lastProgressEmittedTime = now
            if let pos = message.position {
                lastEmittedPosition = pos
            }
        } else {
            // For play, pause, ended, or disconnect: reset rate limiter
            lastProgressEmittedTime = Date()
            if let pos = message.position {
                lastEmittedPosition = pos
            }
        }
        
        // Update session tracking
        self.activeSessionId = incomingSessionId
        self.lastEventTimestamp = msgTime
        
        if message.event == .ended || message.event == .disconnect {
            self.activeSessionId = nil
            self.lastEmittedPosition = -1
        }
        
        onMessageReceived?(message)
    }
    
    /// Simulates or injects a message directly (useful for tests and in-process bridge).
    public func postMessageDirectly(_ message: ChromeMediaMessage) {
        processIncomingMessage(message)
    }
}
