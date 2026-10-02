import CoreAudio
import Foundation

/// Monitors system audio volume and mute status using public CoreAudio APIs without polling.
/// Dynamically tracks default output device changes (e.g., AirPods, external monitors, built-in speakers).
public final class VolumeMonitor: @unchecked Sendable {
    
    public var onVolumeChanged: ((Float, Bool) -> Void)?
    
    private let lock = NSLock()
    private var defaultOutputDeviceId: AudioObjectID = 0
    private var isListening: Bool = false
    
    // Track registered addresses on the current device to unregister cleanly
    private var registeredDeviceAddresses: [AudioObjectPropertyAddress] = []
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
        
        // Listen for default output device changes at the system level
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.global(qos: .userInteractive)
        ) { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        
        updateDefaultDeviceId()
        registerDeviceListeners()
    }
    
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isListening else { return }
        isListening = false
        
        // Unregister system default device listener
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.global(qos: .userInteractive)
        ) { _, _ in }
        
        unregisterDeviceListeners()
    }
    
    /// Reads the current system output volume (0.0 to 1.0) and mute status reliably across hardware channels.
    public func getCurrentVolume() -> (volume: Float, isMuted: Bool) {
        lock.lock()
        if defaultOutputDeviceId == 0 {
            updateDefaultDeviceId()
        }
        let deviceId = defaultOutputDeviceId
        lock.unlock()
        
        guard deviceId != 0 else { return (0.5, false) }
        
        var volume: Float32 = 0.0
        var foundVolume = false
        
        // Attempt Channel 1 (primary channel on MacBook built-in speakers)
        var size1 = UInt32(MemoryLayout<Float32>.size)
        var address1 = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 1
        )
        if AudioObjectGetPropertyData(deviceId, &address1, 0, nil, &size1, &volume) == noErr {
            foundVolume = true
        }
        
        // Fallback to Main Element (0)
        if !foundVolume {
            var sizeMain = UInt32(MemoryLayout<Float32>.size)
            var addressMain = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(deviceId, &addressMain, 0, nil, &sizeMain, &volume) == noErr {
                foundVolume = true
            }
        }
        
        // Fallback to Channel 2
        if !foundVolume {
            var size2 = UInt32(MemoryLayout<Float32>.size)
            var address2 = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 2
            )
            _ = AudioObjectGetPropertyData(deviceId, &address2, 0, nil, &size2, &volume)
        }
        
        // Mute state
        var isMuted: UInt32 = 0
        var foundMute = false
        
        var muteSizeMain = UInt32(MemoryLayout<UInt32>.size)
        var muteAddressMain = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceId, &muteAddressMain, 0, nil, &muteSizeMain, &isMuted) == noErr {
            foundMute = true
        }
        
        if !foundMute {
            var muteSize1 = UInt32(MemoryLayout<UInt32>.size)
            var muteAddress1 = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 1
            )
            _ = AudioObjectGetPropertyData(deviceId, &muteAddress1, 0, nil, &muteSize1, &isMuted)
        }
        
        return (min(max(volume, 0.0), 1.0), isMuted != 0)
    }
    
    private func updateDefaultDeviceId() {
        var defaultDevice: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultDevice)
        if status == noErr {
            self.defaultOutputDeviceId = defaultDevice
        }
    }
    
    private func handleDefaultDeviceChanged() {
        lock.lock()
        unregisterDeviceListeners()
        updateDefaultDeviceId()
        registerDeviceListeners()
        lock.unlock()
        
        emitCurrentVolume()
    }
    
    private func registerDeviceListeners() {
        guard defaultOutputDeviceId != 0 else { return }
        let device = defaultOutputDeviceId
        
        // Candidate addresses covering channel 1, channel 2, main element, and wildcard
        let candidates: [AudioObjectPropertyAddress] = [
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: 1),
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: 2),
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain),
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementWildcard),
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: 1),
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain),
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementWildcard)
        ]
        
        for var addr in candidates {
            let status = AudioObjectAddPropertyListenerBlock(device, &addr, DispatchQueue.global(qos: .userInteractive)) { [weak self] _, _ in
                self?.emitCurrentVolume()
            }
            if status == noErr {
                registeredDeviceAddresses.append(addr)
            }
        }
    }
    
    private func unregisterDeviceListeners() {
        guard defaultOutputDeviceId != 0 else { return }
        let device = defaultOutputDeviceId
        
        for var addr in registeredDeviceAddresses {
            AudioObjectRemovePropertyListenerBlock(device, &addr, DispatchQueue.global(qos: .userInteractive)) { _, _ in }
        }
        registeredDeviceAddresses.removeAll()
    }
    
    private func emitCurrentVolume() {
        let (volume, isMuted) = getCurrentVolume()
        DispatchQueue.main.async { [weak self] in
            self?.onVolumeChanged?(volume, isMuted)
        }
    }
    
    /// Utility for clamping volume between 0.0 and 1.0.
    public static func clampVolume(_ value: Float) -> Float {
        return min(max(value, 0.0), 1.0)
    }
}
