import CoreAudio
import Foundation

/// Represents a detected audio hardware device transition.
public struct AudioDeviceInfo: Equatable, Sendable {
    public let name: String
    public let isConnected: Bool
    public let iconSymbol: String
    
    public init(name: String, isConnected: Bool, iconSymbol: String) {
        self.name = name
        self.isConnected = isConnected
        self.iconSymbol = iconSymbol
    }
}

/// Event-driven audio device monitor using public CoreAudio property listeners.
/// Detects output device switches (e.g. AirPods, Bluetooth headphones, built-in speakers) without polling.
public final class AudioDeviceMonitor: @unchecked Sendable {
    
    public var onDeviceChanged: ((AudioDeviceInfo) -> Void)?
    
    private let lock = NSLock()
    private var isListening: Bool = false
    private var lastDeviceName: String?
    
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    public init() {}
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isListening else { return }
        isListening = true
        
        lastDeviceName = getCurrentOutputDeviceName()
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.global(qos: .userInitiated)
        ) { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
    }
    
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isListening else { return }
        isListening = false
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.global(qos: .userInitiated)
        ) { _, _ in }
    }
    
    /// Reads the human-readable name of the current default output audio device.
    public func getCurrentOutputDeviceName() -> String {
        var deviceId = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &size,
            &deviceId
        )
        guard status == noErr, deviceId != 0 else {
            return "Mac Speakers"
        }
        
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var cfName: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let nameStatus = AudioObjectGetPropertyData(deviceId, &nameAddress, 0, nil, &nameSize, &cfName)
        
        if nameStatus == noErr, let unmanaged = cfName {
            let str = (unmanaged.takeRetainedValue() as String).trimmingCharacters(in: .whitespacesAndNewlines)
            if !str.isEmpty {
                return str
            }
        }
        
        return "Mac Speakers"
    }
    
    public static func resolveIcon(for deviceName: String) -> String {
        let lower = deviceName.lowercased()
        if lower.contains("airpod") {
            return "airpodspro"
        } else if lower.contains("headphone") || lower.contains("headset") || lower.contains("wh-") || lower.contains("beats") {
            return "headphones"
        } else if lower.contains("display") || lower.contains("monitor") || lower.contains("hdmi") {
            return "display"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    private func handleDefaultDeviceChanged() {
        let newName = getCurrentOutputDeviceName()
        
        lock.lock()
        let previous = lastDeviceName
        lastDeviceName = newName
        lock.unlock()
        
        guard newName != previous else { return }
        
        let icon = Self.resolveIcon(for: newName)
        let info = AudioDeviceInfo(name: newName, isConnected: true, iconSymbol: icon)
        
        DispatchQueue.main.async { [weak self] in
            self?.onDeviceChanged?(info)
        }
    }
    
    /// Simulates device connection/disconnection for testing and validation.
    public func simulateDeviceChange(name: String, isConnected: Bool = true) {
        let icon = Self.resolveIcon(for: name)
        let info = AudioDeviceInfo(name: name, isConnected: isConnected, iconSymbol: icon)
        onDeviceChanged?(info)
    }
}
