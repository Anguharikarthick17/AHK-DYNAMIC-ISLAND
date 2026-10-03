import AppKit
import Foundation

/// Manages dynamic resolution and presentation of the local Mac's computer name.
/// Replaces hardcoded identities with the actual user-facing local device name.
public final class DeviceIdentityManager: @unchecked Sendable {
    
    public static let shared = DeviceIdentityManager()
    
    public private(set) var computerName: String
    private let lock = NSLock()
    
    public init(nameResolver: (() -> String?)? = nil) {
        if let customResolver = nameResolver, let customName = customResolver() {
            self.computerName = Self.format(customName)
        } else {
            self.computerName = Self.resolveSystemComputerName()
        }
    }
    
    /// Resolves the user-facing local computer name using standard macOS public APIs.
    /// Priority:
    /// 1. Host.current().localizedName (e.g. "ANGU’s MacBook Air", "John's MacBook Pro")
    /// 2. ProcessInfo.processInfo.hostName (system hostname fallback)
    /// 3. "THIS MAC" (safe final fallback)
    public static func resolveSystemComputerName() -> String {
        return resolve(
            localizedName: Host.current().localizedName,
            hostName: ProcessInfo.processInfo.hostName
        )
    }
    
    /// Pure resolution logic supporting unit testing of system fallbacks.
    public static func resolve(localizedName: String?, hostName: String?) -> String {
        // 1. Host.current().localizedName
        if let localized = localizedName,
           !localized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return format(localized)
        }
        
        // 2. Hostname fallback
        if let host = hostName {
            let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedHost.isEmpty && trimmedHost != "localhost" {
                let clean = trimmedHost.components(separatedBy: ".").first ?? trimmedHost
                if !clean.isEmpty {
                    return format(clean)
                }
            }
        }
        
        // 3. Final safe fallback
        return "THIS MAC"
    }
    
    /// Formats the computer name into uppercase, trimmed presentation.
    public static func format(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "THIS MAC" }
        return trimmed.uppercased()
    }
    
    public private(set) var secondaryInfo: String? = nil
    
    /// Returns the complete presentation string for the idle capsule.
    /// If secondary info is present and fits, formats e.g. "ANGU’S MACBOOK AIR   ⚡ 67%"
    public var fullIdlePresentation: String {
        lock.lock()
        defer { lock.unlock() }
        if let sec = secondaryInfo, !sec.isEmpty {
            return "\(computerName)   \(sec)"
        }
        return computerName
    }
    
    /// Computes the recommended idle capsule width based on text measurement.
    /// Minimum width: 150 pt, Maximum width: 220 pt.
    public var idleCapsuleWidth: CGFloat {
        let text = fullIdlePresentation
        return Self.calculateCapsuleWidth(for: text)
    }
    
    public static func calculateCapsuleWidth(for text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11.0, weight: .semibold)
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .kern: 0.6
        ])
        let textWidth = ceil(attr.size().width)
        let requiredWidth = textWidth + 36.0 // 18pt padding including AHK signature glyph
        let clamped = min(max(150.0, requiredWidth), 220.0)
        return clamped.rounded()
    }
    
    /// Updates the secondary status information (e.g. from event-driven BatteryMonitor).
    public func setSecondaryInfo(_ info: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.secondaryInfo = info
    }
    
    /// Updates secondary info using battery state: "⚡ 67%" or "• 67%".
    public func updateSecondaryBattery(level: Float, isCharging: Bool) {
        let pct = Int((level * 100).rounded())
        let text = isCharging ? "⚡ \(pct)%" : "• \(pct)%"
        setSecondaryInfo(text)
    }
    
    /// Updates the computer name (useful for testing or runtime profile changes).
    public func setComputerName(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        self.computerName = Self.format(name)
    }
}
