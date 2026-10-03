import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class MediaAndAudioIntelligenceTests: XCTestCase {

    // MARK: - Media Intelligence Tests

    func testMediaPlayingStateAndWaveform() {
        let playingItem = NowPlayingState(
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            isPlaying: true,
            appName: "Music"
        )

        let mediaView = NowPlayingView()
        mediaView.update(state: playingItem, isExpanded: false)

        XCTAssertTrue(playingItem.isPlaying)
        XCTAssertEqual(playingItem.title, "Blinding Lights")
        XCTAssertEqual(playingItem.artist, "The Weeknd")
        XCTAssertTrue(mediaView.waveformView.isPlaying)
    }

    func testMediaPausedState() {
        let pausedItem = NowPlayingState(
            title: "Starboy",
            artist: "The Weeknd",
            album: "Starboy",
            isPlaying: false,
            appName: "Music"
        )

        let mediaView = NowPlayingView()
        mediaView.update(state: pausedItem, isExpanded: false)

        XCTAssertFalse(pausedItem.isPlaying)
        XCTAssertFalse(mediaView.waveformView.isPlaying)
    }

    func testMediaStoppedRestoresPreviousActivity() {
        let coordinator = IslandEventCoordinator()
        let playingItem = NowPlayingState(
            title: "Song",
            artist: "Artist",
            isPlaying: true,
            appName: "Music"
        )

        coordinator.postActivity(.nowPlaying(state: playingItem))
        XCTAssertEqual(coordinator.activeActivity, .nowPlaying(state: playingItem))

        // When stopped
        coordinator.removeActivities { act in
            if case .nowPlaying = act { return true }
            return false
        }
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }

    func testMediaMetadataAvailableVsUnavailable() {
        // Full metadata
        let fullItem = NowPlayingState(
            title: "Save Your Tears",
            artist: "The Weeknd",
            album: "After Hours",
            isPlaying: true,
            appName: "Music"
        )
        XCTAssertEqual(fullItem.title, "Save Your Tears")
        XCTAssertEqual(fullItem.artist, "The Weeknd")

        // Unavailable/generic metadata (e.g. YouTube playing in Chrome without public script)
        let genericItem = NowPlayingState(
            title: "Chrome • Playing",
            artist: "Google Chrome",
            album: nil,
            isPlaying: true,
            appName: "Chrome"
        )
        XCTAssertEqual(genericItem.title, "Chrome • Playing")
        XCTAssertEqual(genericItem.artist, "Google Chrome")
    }

    func testMediaProgressUnavailableSafety() {
        // Ensures progress is not fabricated or faked
        let item = NowPlayingState(
            title: "Track",
            artist: "Artist",
            isPlaying: true,
            playbackProgress: 0.0,
            duration: 0.0,
            elapsedTime: 0.0
        )
        XCTAssertEqual(item.duration, 0.0)
        XCTAssertEqual(item.elapsedTime, 0.0)
        XCTAssertEqual(item.playbackProgress, 0.0)
    }

    // MARK: - Audio Device Intelligence Tests

    func testAudioDeviceMonitorAndModel() {
        let airPods = AudioDeviceInfo(
            name: "AirPods Pro",
            isConnected: true,
            iconSymbol: "airpodspro"
        )

        XCTAssertEqual(airPods.name, "AirPods Pro")
        XCTAssertEqual(airPods.iconSymbol, "airpodspro")
        XCTAssertTrue(airPods.isConnected)

        let speakers = AudioDeviceInfo(
            name: "MacBook Speakers",
            isConnected: true,
            iconSymbol: "speaker.wave.2.fill"
        )
        XCTAssertEqual(speakers.name, "MacBook Speakers")
        XCTAssertEqual(speakers.iconSymbol, "speaker.wave.2.fill")
    }

    func testAudioDeviceViewPresentation() {
        let view = AudioDeviceView()
        view.update(name: "AirPods Pro", isConnected: true, icon: "airpodspro")

        XCTAssertEqual(view.deviceLabel.stringValue, "AirPods Pro")
        XCTAssertEqual(view.statusLabel.stringValue, "Connected")
    }

    func testAudioDeviceEventInCoordinator() {
        let coordinator = IslandEventCoordinator()
        let act = IslandActivity.audioDevice(name: "AirPods Pro", isConnected: true, icon: "airpodspro")

        coordinator.postActivity(act)
        XCTAssertEqual(coordinator.activeActivity, act)
        XCTAssertTrue(coordinator.activeActivity.isTransientHUD)
    }

    func testAudioDevicePreemptsAndRestoresMedia() {
        let coordinator = IslandEventCoordinator()
        let item = NowPlayingState(title: "Track", artist: "Artist", isPlaying: true)
        let mediaAct = IslandActivity.nowPlaying(state: item)
        coordinator.postActivity(mediaAct)
        XCTAssertEqual(coordinator.activeActivity, mediaAct)

        let audioAct = IslandActivity.audioDevice(name: "MacBook Speakers", isConnected: true, icon: "speaker.wave.2.fill")
        coordinator.postActivity(audioAct)

        // Preempts
        XCTAssertEqual(coordinator.activeActivity, audioAct)

        // When transient finishes
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, mediaAct)
    }
}
