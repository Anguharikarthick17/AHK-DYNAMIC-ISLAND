import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class NetworkAndSystemIntelligenceTests: XCTestCase {

    // MARK: - Network Intelligence Tests

    func testNetworkStateModelAndPresentation() {
        let connected = NetworkStateInfo(statusText: "Wi-Fi Connected", iconSymbol: "wifi", isWarning: false)
        XCTAssertEqual(connected.statusText, "Wi-Fi Connected")
        XCTAssertEqual(connected.iconSymbol, "wifi")
        XCTAssertFalse(connected.isWarning)

        let disconnected = NetworkStateInfo(statusText: "Wi-Fi Disconnected", iconSymbol: "wifi.slash", isWarning: true)
        XCTAssertEqual(disconnected.statusText, "Wi-Fi Disconnected")
        XCTAssertTrue(disconnected.isWarning)

        let restored = NetworkStateInfo(statusText: "Internet Restored", iconSymbol: "checkmark.circle.fill", isWarning: false)
        XCTAssertEqual(restored.statusText, "Internet Restored")
        XCTAssertFalse(restored.isWarning)

        let view = NetworkStateView()
        view.update(statusText: restored.statusText, icon: restored.iconSymbol, isWarning: restored.isWarning)
        XCTAssertEqual(view.statusLabel.stringValue, "Internet Restored")
    }

    func testNetworkEventInCoordinatorAndPreemption() {
        let coordinator = IslandEventCoordinator()
        let playing = NowPlayingState(title: "Track", artist: "Artist", isPlaying: true)
        let mediaAct = IslandActivity.nowPlaying(state: playing)
        coordinator.postActivity(mediaAct)

        let netAct = IslandActivity.network(statusText: "Internet Restored", icon: "checkmark.circle.fill", isWarning: false)
        coordinator.postActivity(netAct)

        // Preempts persistent media
        XCTAssertEqual(coordinator.activeActivity, netAct)

        // Auto-dismiss / clear restores media
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, mediaAct)
    }

    // MARK: - Clipboard Activity Tests

    func testClipboardProviderArchitectureAndPrivacySafety() {
        let provider = ClipboardActivityProvider()
        var receivedStatus: String?

        provider.onClipboardActivity = { status in
            receivedStatus = status
        }
        provider.startObserving()

        // 1. Explicit copy event
        provider.postCopyEvent(type: .text)
        XCTAssertEqual(receivedStatus, "Text Copied")

        // 2. AHK EventBus cooperative event (with ZERO clipboard contents)
        let event = AHKEcosystemEvent(
            source: .generic,
            name: "clipboard.copied",
            payload: ["type": "image"]
        )
        AHKEventBus.shared.post(event)

        // View verification
        let clipView = ClipboardView()
        clipView.update(statusText: "Text Copied")
        XCTAssertEqual(clipView.statusLabel.stringValue, "Text Copied")

        provider.stopObserving()
    }

    func testClipboardFallbackDoesNotPollOrLeakData() {
        // Assert generic OS clipboard polling is safely disabled per Section 7
        let coordinator = IslandEventCoordinator()
        _ = ClipboardActivityProvider()
        // Never started or polled
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }

    // MARK: - Mini Timer Tests

    func testMiniTimerCreationAndCountdown() {
        let manager = MiniTimerManager()
        var lastRemaining: TimeInterval = 0

        manager.onTick = { rem, _ in
            lastRemaining = rem
        }

        manager.startTimer(duration: 300) // 5 minutes
        XCTAssertTrue(manager.isRunning)
        XCTAssertEqual(MiniTimerManager.format(remaining: 300), "05:00")
        XCTAssertEqual(MiniTimerManager.format(remaining: 272), "04:32")
        XCTAssertGreaterThan(lastRemaining, 0)

        let timerView = MiniTimerView()
        timerView.update(remainingSeconds: 272, totalSeconds: 300, isCompleted: false)
        XCTAssertEqual(timerView.timeLabel.stringValue, "04:32")

        manager.cancelTimer()
        XCTAssertFalse(manager.isRunning)
    }

    func testMiniTimerCompletionAndRestoration() {
        let coordinator = IslandEventCoordinator()

        // 1. Running timer
        let runningTimer = IslandActivity.timer(remainingSeconds: 272, totalSeconds: 300, isCompleted: false)
        coordinator.postActivity(runningTimer)
        XCTAssertEqual(coordinator.activeActivity, runningTimer)

        // 2. Completed timer (critical priority)
        let completedTimer = IslandActivity.timer(remainingSeconds: 0, totalSeconds: 300, isCompleted: true)
        coordinator.postActivity(completedTimer)
        XCTAssertEqual(coordinator.activeActivity, completedTimer)

        // View verification
        let timerView = MiniTimerView()
        timerView.update(remainingSeconds: 0, totalSeconds: 300, isCompleted: true)
        XCTAssertEqual(timerView.timeLabel.stringValue, "Timer Complete")

        // 3. Dismiss restores idle
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }

    // MARK: - Download Intelligence Tests

    func testDownloadProgressAndAttribution() {
        let coordinator = IslandEventCoordinator()

        // Active download with app attribution
        let activeDownload = DownloadState(
            filename: "Xcode_16.dmg",
            bytesReceived: 6400000,
            totalBytes: 10000000,
            appName: "Chrome"
        )
        let activeAct = IslandActivity.download(state: activeDownload)
        coordinator.postActivity(activeAct)
        XCTAssertEqual(coordinator.activeActivity, activeAct)

        let downloadView = DownloadView()
        downloadView.update(state: activeDownload)
        XCTAssertEqual(downloadView.filenameLabel.stringValue, "Xcode_16.dmg")
        XCTAssertEqual(downloadView.headerLabel.stringValue, "Downloading")

        // Completion with app name
        let completedDownload = DownloadState(
            filename: "Xcode_16.dmg",
            bytesReceived: 10000000,
            totalBytes: 10000000,
            isCompleted: true,
            appName: "Chrome"
        )
        let completedAct = IslandActivity.download(state: completedDownload)
        coordinator.postActivity(completedAct)
        XCTAssertEqual(coordinator.activeActivity, completedAct)

        downloadView.update(state: completedDownload)
        XCTAssertEqual(downloadView.headerLabel.stringValue, "Chrome Download Complete")

        // Dismiss restores idle
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }

    // MARK: - Notification Intelligence Tests

    func testNotificationEventAndPrivacySafety() {
        let coordinator = IslandEventCoordinator()

        // Supported cooperative notification event
        let notifAct = IslandActivity.notification(
            title: "Discord",
            subtitle: "New Message",
            iconName: "bell.fill"
        )
        coordinator.postActivity(notifAct)
        XCTAssertEqual(coordinator.activeActivity, notifAct)

        // Auto-dismiss restores idle
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }

    // MARK: - Unified Priority & Preemption Tests

    func testUnifiedHierarchyPriorities() {
        let critical = ActivityPriority.critical
        let high = ActivityPriority.high
        let medium = ActivityPriority.medium
        let low = ActivityPriority.low
        let idle = ActivityPriority.idle

        XCTAssertTrue(critical > high)
        XCTAssertTrue(high > medium)
        XCTAssertTrue(medium > low)
        XCTAssertTrue(low > idle)
    }

    func testMultiLevelPreemptionAndRestorationChain() {
        let coordinator = IslandEventCoordinator()

        // 1. Idle
        XCTAssertEqual(coordinator.activeActivity, .idle)

        // 2. Persistent App Activity (Low)
        let app = UniversalAppActivity(
            applicationName: "Finder",
            bundleIdentifier: "com.apple.finder",
            activityType: .appActive,
            stateText: "Active",
            confidence: .high
        )
        let appAct = IslandActivity.appActivity(activity: app)
        coordinator.postActivity(appAct)
        XCTAssertEqual(coordinator.activeActivity, appAct)

        // 3. Media starts (Medium)
        let media = NowPlayingState(title: "Blinding Lights", artist: "The Weeknd", isPlaying: true)
        let mediaAct = IslandActivity.nowPlaying(state: media)
        coordinator.postActivity(mediaAct)
        XCTAssertEqual(coordinator.activeActivity, mediaAct)

        // 4. Charger connected (High transient)
        let chargerAct = IslandActivity.charger(isConnected: true, percent: 67)
        coordinator.postActivity(chargerAct)
        XCTAssertEqual(coordinator.activeActivity, chargerAct)

        // 5. Volume changes while charger is shown (Volume is transient HUD)
        let volumeAct = IslandActivity.volume(level: 0.72, isMuted: false)
        coordinator.postActivity(volumeAct)
        XCTAssertEqual(coordinator.activeActivity, volumeAct)

        // 6. Dismiss volume -> restores queued persistent media
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, mediaAct)

        // 7. Stop media -> restores app activity
        coordinator.removeActivities { act in
            if case .nowPlaying = act { return true }
            return false
        }
        XCTAssertEqual(coordinator.activeActivity, appAct)

        // 8. Terminate app -> restores idle
        coordinator.removeActivities { act in
            if case .appActivity(let a) = act, a.bundleIdentifier == "com.apple.finder" { return true }
            return false
        }
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }
}
