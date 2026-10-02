import CoreAudio
import Foundation

/// Monitors system audio volume and mute status using public CoreAudio APIs without polling.
public final class VolumeMonitor: @unchecked Sendable {
    
    public var onVolumeChanged: ((Float, Bool) -> Void)?
    
    private var defaultOutputDeviceId: AudioObjectID = 0
    private var isListening: Bool = false
    
    public init() {}
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        guard !isListening else { return }
        isListening = true
        
        updateDefaultDeviceId()
        registerListener()
    }
    
    public func stopMonitoring() {
        guard isListening else { return }
        isListening = false
    }
    
    /// Reads the current system output volume (0.0 to 1.0) and mute status.
    public func getCurrentVolume() -> (volume: Float, isMuted: Bool) {
        updateDefaultDeviceId()
        guard defaultOutputDeviceId != 0 else { return (0.5, false) }
        
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(defaultOutputDeviceId, &address, 0, nil, &size, &volume)
        if status != noErr {
            // Try left channel as fallback
            address.mElement = 1
            _ = AudioObjectGetPropertyData(defaultOutputDeviceId, &address, 0, nil, &size, &volume)
        }
        
        var isMuted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectGetPropertyData(defaultOutputDeviceId, &muteAddress, 0, nil, &muteSize, &isMuted)
        
        return (volume, isMuted != 0)
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
    
    private func registerListener() {
        guard defaultOutputDeviceId != 0 else { return }
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementWildcard
        )
        
        AudioObjectAddPropertyListenerBlock(defaultOutputDeviceId, &address, DispatchQueue.main) { [weak self] _, _ in
            guard let self = self else { return }
            let current = self.getCurrentVolume()
            self.onVolumeChanged?(current.volume, current.isMuted)
        }
    }
    
    /// Simulates a volume change for testing or previews.
    public func simulateVolumeChange(level: Float, isMuted: Bool = false) {
        onVolumeChanged?(level, isMuted)
    }
}
