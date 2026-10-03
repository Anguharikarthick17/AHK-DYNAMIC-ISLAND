import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class ChromeMediaActivityTests: XCTestCase {
    
    // MARK: - 1. Message Schema & Validation
    
    func testChromeMediaMessageSchemaAndValidation() {
        // Valid Play Event
        let validPlay = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            sessionId: "yt_test_1",
            title: "Daft Punk - Veridis Quo",
            artist: "Daft Punk",
            position: 154,
            duration: 312,
            timestamp: 1700000000.0,
            artworkUrl: "https://example.com/art.jpg"
        )
        XCTAssertTrue(validPlay.isValid)
        XCTAssertEqual(validPlay.progress ?? 0, 154.0 / 312.0, accuracy: 0.01)
        XCTAssertEqual(validPlay.formattedTimeString, "2:34 / 5:12")
        
        // JSON round-trip
        let encoded = validPlay.encode()
        XCTAssertNotNil(encoded)
        let decoded = ChromeMediaMessage.decode(from: encoded!)
        XCTAssertEqual(decoded, validPlay)
        
        // Invalid Version
        let invalidVersion = ChromeMediaMessage(
            version: 2,
            source: "chrome",
            provider: "youtube",
            event: .play
        )
        XCTAssertFalse(invalidVersion.isValid)
        
        // Invalid Source
        let invalidSource = ChromeMediaMessage(
            version: 1,
            source: "untrusted_source",
            provider: "youtube",
            event: .play
        )
        XCTAssertFalse(invalidSource.isValid)
        
        // Invalid Position / Duration (negative or NaN)
        let negativePos = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            position: -10
        )
        XCTAssertFalse(negativePos.isValid)
        
        let nanDuration = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            duration: Double.nan
        )
        XCTAssertFalse(nanDuration.isValid)
    }
    
    final class TestBox<T>: @unchecked Sendable {
        var items: [T] = []
    }
    
    // MARK: - 2. Progress Coalescing & Stale Event Protection
    
    func testProgressCoalescingAndStaleEventProtection() {
        let bridge = ChromeNativeMessagingBridge()
        bridge.stopObserving() // Disconnect real notifications for isolated testing
        
        let box = TestBox<ChromeMediaMessage>()
        bridge.onMessageReceived = { msg in
            box.items.append(msg)
        }
        
        let t0 = 1700000000.0
        
        // 1. Initial play event should pass immediately
        let playMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            sessionId: "session_a",
            title: "Test Video",
            position: 10,
            duration: 100,
            timestamp: t0
        )
        bridge.processIncomingMessage(playMsg)
        XCTAssertEqual(box.items.count, 1)
        
        // 2. High-frequency tick within 0.1s without seek should be coalesced / dropped
        let rapidTick = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .timeupdate,
            sessionId: "session_a",
            title: "Test Video",
            position: 11,
            duration: 100,
            timestamp: t0 + 0.1
        )
        bridge.processIncomingMessage(rapidTick)
        XCTAssertEqual(box.items.count, 1, "Rapid playback ticks must be coalesced")
        
        // 3. User seek (jump from 10s to 45s) must immediately emit regardless of time interval
        let seekMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .timeupdate,
            sessionId: "session_a",
            title: "Test Video",
            position: 45,
            duration: 100,
            timestamp: t0 + 0.2
        )
        bridge.processIncomingMessage(seekMsg)
        XCTAssertEqual(box.items.count, 2, "User seek must immediately emit")
        XCTAssertEqual(box.items.last?.position, 45)
        
        // 4. Stale event (timestamp < previous event timestamp) must be rejected
        let staleMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .timeupdate,
            sessionId: "session_a",
            title: "Test Video",
            position: 50,
            duration: 100,
            timestamp: t0 - 10.0 // Stale
        )
        bridge.processIncomingMessage(staleMsg)
        XCTAssertEqual(box.items.count, 2, "Stale out-of-order events must be rejected")
    }
    
    // MARK: - 3. Activity Provider & Dynamic Island Presentation
    
    func testChromeMediaActivityProviderPlayPauseEnded() {
        let bridge = ChromeNativeMessagingBridge()
        bridge.stopObserving()
        
        let provider = ChromeMediaActivityProvider(bridge: bridge)
        XCTAssertTrue(provider.isAvailable)
        XCTAssertEqual(provider.category, .media)
        
        let actBox = TestBox<UniversalAppActivity>()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        // 1. Play Event
        let playMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            title: "Lofi Beats - Relaxing Stream",
            artist: "Lofi Girl",
            position: 120,
            duration: 600
        )
        provider.handleChromeMediaMessage(playMsg)
        
        XCTAssertEqual(actBox.items.count, 1)
        let playAct = actBox.items.last!
        XCTAssertEqual(playAct.applicationName, "Google Chrome")
        XCTAssertEqual(playAct.activityTitle, "Lofi Beats - Relaxing Stream")
        XCTAssertEqual(playAct.activitySubtitle, "YouTube • Lofi Girl")
        XCTAssertEqual(playAct.activityState, .playing)
        XCTAssertEqual(playAct.glyph, "▶")
        XCTAssertEqual(playAct.confidence, .high)
        XCTAssertEqual(playAct.priority, .nowPlaying)
        
        // 2. Pause Event
        let pauseMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .pause,
            title: "Lofi Beats - Relaxing Stream",
            artist: "Lofi Girl",
            position: 125,
            duration: 600
        )
        provider.handleChromeMediaMessage(pauseMsg)
        
        XCTAssertEqual(actBox.items.count, 2)
        let pauseAct = actBox.items.last!
        XCTAssertEqual(pauseAct.activityState, .paused)
        XCTAssertEqual(pauseAct.glyph, "⏸")
        XCTAssertEqual(pauseAct.priority, .nowPlaying)
        
        // 3. Ended Event
        let endedMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .ended,
            title: "Lofi Beats - Relaxing Stream"
        )
        provider.handleChromeMediaMessage(endedMsg)
        
        XCTAssertEqual(actBox.items.count, 3)
        let endedAct = actBox.items.last!
        XCTAssertEqual(endedAct.activityState, .completed)
        XCTAssertEqual(endedAct.glyph, "✓")
        XCTAssertEqual(endedAct.priority, .activityCompletion)
    }
    
    // MARK: - 4. Preemption & Restoration Chain
    
    func testChromeMediaPreemptionAndRestorationChain() {
        let coordinator = IslandEventCoordinator()
        
        // 1. YouTube media playing
        let ytActivity = UniversalAppActivity(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            activityType: .mediaPlaying,
            activityTitle: "Cyberpunk Soundtrack",
            activitySubtitle: "YouTube • Night City",
            activityState: .playing,
            progress: 0.35,
            priority: .nowPlaying,
            confidence: .high,
            glyph: "▶"
        )
        let ytIslandAct = IslandActivity.appActivity(activity: ytActivity)
        coordinator.postActivity(ytIslandAct)
        XCTAssertEqual(coordinator.activeActivity, ytIslandAct)
        
        // 2. Volume adjustment occurs
        let volumeAct = IslandActivity.volume(level: 0.65, isMuted: false)
        coordinator.postActivity(volumeAct)
        XCTAssertEqual(coordinator.activeActivity, volumeAct)
        
        // 3. Volume HUD expires -> YouTube playback is restored!
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, ytIslandAct, "YouTube playback must be restored after volume HUD dismisses")
        
        // 4. Higher priority Xcode build begins
        let xcodeBuild = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .building,
            activityTitle: "Building App",
            activityState: .building,
            priority: .appTask,
            glyph: "🔨"
        )
        let buildIslandAct = IslandActivity.appActivity(activity: xcodeBuild)
        coordinator.postActivity(buildIslandAct)
        XCTAssertEqual(coordinator.activeActivity, buildIslandAct, "Xcode build must preempt media playback")
        
        // 5. Xcode build completes and dismisses -> YouTube playback is restored!
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, ytIslandAct, "YouTube playback must restore when higher priority task finishes")
    }
    
    // MARK: - 5. Disconnect Cleanup
    
    func testChromeDisconnectCleansUpRegistry() {
        let registry = UniversalActivityRegistry.shared
        let provider = ChromeMediaActivityProvider()
        
        // Post active play
        let playMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            title: "Test Track"
        )
        provider.handleChromeMediaMessage(playMsg)
        
        XCTAssertNotNil(registry.allActivities().first(where: { $0.bundleIdentifier == "com.google.Chrome" }))
        
        // Chrome closes / disconnects
        let disconnectMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .disconnect
        )
        provider.handleChromeMediaMessage(disconnectMsg)
        
        // Registry must be cleanly purged
        XCTAssertNil(registry.allActivities().first(where: { $0.bundleIdentifier == "com.google.Chrome" }),
                     "Chrome activity must be removed upon disconnect")
    }
    
    // MARK: - 6. AppActivityView YouTube Formatting
    
    func testAppActivityViewYouTubeFormatting() {
        let view = AppActivityView(frame: NSRect(x: 0, y: 0, width: 235, height: 40))
        
        let ytActivity = UniversalAppActivity(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            activityType: .mediaPlaying,
            activityTitle: "Rick Astley - Never Gonna Give You Up",
            activitySubtitle: "YouTube • Official",
            activityState: .playing,
            progress: 0.5,
            priority: .nowPlaying,
            glyph: "▶",
            metadata: [
                "provider": "youtube",
                "timeString": "2:34 / 5:12"
            ]
        )
        view.update(activity: ytActivity)
        
        XCTAssertEqual(view.currentActivity?.activityTitle, "Rick Astley - Never Gonna Give You Up")
        XCTAssertEqual(view.currentActivity?.metadata["timeString"], "2:34 / 5:12")
    }
    
    // MARK: - 7. Native Messaging Manifest & Origin Validation
    
    func testNativeMessagingManifestAndOriginValidation() {
        let manifestUrl = URL(fileURLWithPath: "NativeMessaging/com.ahk.dynamicisland.chrome.json")
        guard let data = try? Data(contentsOf: manifestUrl),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Native messaging manifest must exist and be valid JSON")
            return
        }
        
        XCTAssertEqual(json["name"] as? String, "com.ahk.dynamicisland.chrome")
        XCTAssertEqual(json["type"] as? String, "stdio")
        
        let path = json["path"] as? String ?? ""
        XCTAssertTrue(path.hasSuffix("AHKChromeMediaHost"))
        
        let origins = json["allowed_origins"] as? [String] ?? []
        XCTAssertFalse(origins.isEmpty, "allowed_origins must not be empty")
        
        // Ensure no wildcard extension IDs exist (which causes 'Specified native messaging host not found')
        for origin in origins {
            XCTAssertFalse(origin.contains("chrome-extension://*/"), "Wildcard origin must NOT be used")
            XCTAssertTrue(origin.hasPrefix("chrome-extension://"), "Origins must start with chrome-extension://")
        }
        
        // Actual Extension ID verification
        let targetId = "lijlklgicnimjeejfbbijfabmoagfpfe"
        let matches = origins.contains { $0.contains(targetId) }
        XCTAssertTrue(matches, "allowed_origins must contain the actual extension ID")
    }
    
    // MARK: - 8. Reconnect & Session Switching
    
    func testChromeMediaReconnectAndSessionSwitching() {
        let registry = UniversalActivityRegistry.shared
        let provider = ChromeMediaActivityProvider()
        
        // Session A playing
        let msgA = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            sessionId: "session_video_A",
            title: "Video A",
            timestamp: 1700000000.0
        )
        provider.handleChromeMediaMessage(msgA)
        
        var current = registry.allActivities().first(where: { $0.bundleIdentifier == "com.google.Chrome" })
        XCTAssertEqual(current?.activityTitle, "Video A")
        
        // Disconnect
        let discMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .disconnect
        )
        provider.handleChromeMediaMessage(discMsg)
        XCTAssertNil(registry.allActivities().first(where: { $0.bundleIdentifier == "com.google.Chrome" }))
        
        // Reconnect with Session B playing
        let msgB = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            sessionId: "session_video_B",
            title: "Video B",
            timestamp: 1700000010.0
        )
        provider.handleChromeMediaMessage(msgB)
        
        current = registry.allActivities().first(where: { $0.bundleIdentifier == "com.google.Chrome" })
        XCTAssertEqual(current?.activityTitle, "Video B", "Reconnecting session must successfully re-register activity")
    }
}

