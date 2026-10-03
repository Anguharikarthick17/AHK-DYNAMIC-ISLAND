import Foundation
import Network

/// Represents a network connectivity transition.
public struct NetworkStateInfo: Equatable, Sendable {
    public let statusText: String
    public let iconSymbol: String
    public let isWarning: Bool
    
    public init(statusText: String, iconSymbol: String, isWarning: Bool) {
        self.statusText = statusText
        self.iconSymbol = iconSymbol
        self.isWarning = isWarning
    }
}

/// Event-driven network reachability and state monitor using NWPathMonitor.
/// Never polls, never captures packets, never tracks traffic. Zero network transmission.
public final class NetworkMonitor: @unchecked Sendable {
    
    public var onNetworkStateChanged: ((NetworkStateInfo) -> Void)?
    
    private let pathMonitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.ahk.dynamicisland.networkmonitor", qos: .utility)
    private var lastStatus: NWPath.Status?
    private var isStarted = false
    private let lock = NSLock()
    
    public init() {
        self.pathMonitor = NWPathMonitor()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isStarted else { return }
        isStarted = true
        
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        pathMonitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isStarted else { return }
        isStarted = false
        pathMonitor.cancel()
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        lock.lock()
        let previousStatus = lastStatus
        lastStatus = path.status
        lock.unlock()
        
        // Only emit if there is an actual state transition
        guard let prev = previousStatus else { return } // Skip initial baseline
        guard prev != path.status else { return }
        
        let info: NetworkStateInfo
        if path.status == .satisfied {
            info = NetworkStateInfo(
                statusText: "Internet Restored",
                iconSymbol: "checkmark.circle.fill",
                isWarning: false
            )
        } else {
            let isWifi = path.usesInterfaceType(.wifi)
            let name = isWifi ? "Wi-Fi Disconnected" : "Network Disconnected"
            info = NetworkStateInfo(
                statusText: name,
                iconSymbol: "wifi.slash",
                isWarning: true
            )
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onNetworkStateChanged?(info)
        }
    }
    
    /// Simulates network transitions for unit tests and validation.
    public func simulateStateChange(statusText: String, iconSymbol: String, isWarning: Bool) {
        let info = NetworkStateInfo(statusText: statusText, iconSymbol: iconSymbol, isWarning: isWarning)
        onNetworkStateChanged?(info)
    }
}
