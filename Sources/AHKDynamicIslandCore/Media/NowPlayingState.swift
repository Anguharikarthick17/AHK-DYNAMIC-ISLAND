import AppKit
import Foundation

/// Represents the playback state of current media (Music, Spotify, system).
public struct NowPlayingState: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let isPlaying: Bool
    public let playbackProgress: Double // 0.0 to 1.0
    public let duration: TimeInterval
    public let elapsedTime: TimeInterval
    public let appName: String?
    
    public init(
        title: String,
        artist: String,
        album: String? = nil,
        isPlaying: Bool = false,
        playbackProgress: Double = 0.0,
        duration: TimeInterval = 0.0,
        elapsedTime: TimeInterval = 0.0,
        appName: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.playbackProgress = min(max(playbackProgress, 0.0), 1.0)
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.appName = appName
    }
}
