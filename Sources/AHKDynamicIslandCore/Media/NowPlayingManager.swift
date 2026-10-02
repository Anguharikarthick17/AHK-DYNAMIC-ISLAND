import AppKit
import Foundation

/// Manages Now Playing media metadata and controls using public macOS APIs.
@MainActor
public final class NowPlayingManager: NSObject {
    
    public var onPlaybackStateChanged: ((NowPlayingState) -> Void)?
    public private(set) var currentState: NowPlayingState?
    
    public override init() {
        super.init()
        setupObservers()
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    private func setupObservers() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }
    
    @objc private func handleMusicNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let playerState = userInfo["Player State"] as? String ?? "Stopped"
        let isPlaying = (playerState == "Playing")
        let title = userInfo["Name"] as? String ?? "Unknown Title"
        let artist = userInfo["Artist"] as? String ?? "Unknown Artist"
        let album = userInfo["Album"] as? String
        let totalTime = (userInfo["Total Time"] as? Double ?? 0.0) / 1000.0
        let elapsedTime = userInfo["Player Position"] as? Double ?? 0.0
        let progress = totalTime > 0 ? (elapsedTime / totalTime) : 0.0
        
        let state = NowPlayingState(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            playbackProgress: progress,
            duration: totalTime,
            elapsedTime: elapsedTime,
            appName: "Music"
        )
        self.currentState = state
        onPlaybackStateChanged?(state)
    }
    
    @objc private func handleSpotifyNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let playerState = userInfo["Player State"] as? String ?? "Stopped"
        let isPlaying = (playerState == "Playing")
        let title = userInfo["Name"] as? String ?? "Unknown Title"
        let artist = userInfo["Artist"] as? String ?? "Unknown Artist"
        let album = userInfo["Album"] as? String
        let totalTime = (userInfo["Duration"] as? Double ?? 0.0) / 1000.0
        let progress = userInfo["Playback Position"] as? Double ?? 0.0
        
        let state = NowPlayingState(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            playbackProgress: totalTime > 0 ? (progress / totalTime) : 0.0,
            duration: totalTime,
            elapsedTime: progress,
            appName: "Spotify"
        )
        self.currentState = state
        onPlaybackStateChanged?(state)
    }
    
    /// Public media control action (Play / Pause toggle).
    public func togglePlayPause() {
        let script = "tell application \"Music\" to playpause"
        executeAppleScript(script)
    }
    
    public func nextTrack() {
        let script = "tell application \"Music\" to next track"
        executeAppleScript(script)
    }
    
    public func previousTrack() {
        let script = "tell application \"Music\" to previous track"
        executeAppleScript(script)
    }
    
    /// Simulates media playback for unit testing or demonstrations.
    public func simulateTrack(title: String, artist: String, album: String? = nil, isPlaying: Bool = true, progress: Double = 0.35) {
        let state = NowPlayingState(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            playbackProgress: progress,
            duration: 210.0,
            elapsedTime: 73.5,
            appName: "Music"
        )
        self.currentState = state
        onPlaybackStateChanged?(state)
    }
    
    private func executeAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
}
