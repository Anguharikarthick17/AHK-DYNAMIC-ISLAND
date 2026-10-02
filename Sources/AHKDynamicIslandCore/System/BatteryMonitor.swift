import Foundation
import IOKit.ps

/// Battery status snapshot.
public struct BatteryInfo: Equatable, Sendable {
    public let level: Float // 0.0 to 1.0
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let isLow: Bool
    public let isCritical: Bool
    
    public init(level: Float, isCharging: Bool, isPluggedIn: Bool) {
        self.level = min(max(level, 0.0), 1.0)
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isLow = level <= 0.20 && !isCharging
        self.isCritical = level <= 0.10 && !isCharging
    }
}

/// Event-driven battery monitor using public IOKit power source APIs. Zero polling.
public final class BatteryMonitor: @unchecked Sendable {
    
    public var onBatteryStatusChanged: ((BatteryInfo) -> Void)?
    private var runLoopSource: CFRunLoopSource?
    
    public init() {}
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        guard runLoopSource == nil else { return }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handlePowerSourceChange()
        }, context).takeRetainedValue()
        
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        self.runLoopSource = source
    }
    
    public func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            self.runLoopSource = nil
        }
    }
    
    /// Reads the current battery status on demand.
    public func getCurrentBatteryInfo() -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return BatteryInfo(level: 1.0, isCharging: false, isPluggedIn: true)
        }
        
        for ps in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                let current = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
                let maxCap = (desc[kIOPSMaxCapacityKey] as? Int) ?? 100
                let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                let powerState = (desc[kIOPSPowerSourceStateKey] as? String) ?? ""
                let isPlugged = (powerState == kIOPSACPowerValue)
                
                let level = maxCap > 0 ? Float(current) / Float(maxCap) : 1.0
                return BatteryInfo(level: level, isCharging: isCharging, isPluggedIn: isPlugged)
            }
        }
        
        return BatteryInfo(level: 1.0, isCharging: false, isPluggedIn: true)
    }
    
    private func handlePowerSourceChange() {
        let info = getCurrentBatteryInfo()
        DispatchQueue.main.async { [weak self] in
            self?.onBatteryStatusChanged?(info)
        }
    }
    
    /// Simulates a battery event for unit testing or demonstrations.
    public func simulateBattery(level: Float, isCharging: Bool, isPluggedIn: Bool) {
        let info = BatteryInfo(level: level, isCharging: isCharging, isPluggedIn: isPluggedIn)
        onBatteryStatusChanged?(info)
    }
}
