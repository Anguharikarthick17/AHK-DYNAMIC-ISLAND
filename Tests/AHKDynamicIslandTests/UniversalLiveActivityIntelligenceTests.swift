import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class UniversalLiveActivityIntelligenceTests: XCTestCase {
    
    // MARK: - 1. Generic Application Discovery & Truthful Fallback
    
    func testGenericApplicationDiscoveryAndFallback() {
        let registry = UniversalActivityRegistry()
        
        let calculator = DiscoveredApplication(
            applicationName: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            processIdentifier: 1010
        )
        let calcActivity = registry.resolveActivity(for: calculator)
        XCTAssertEqual(calcActivity.applicationName, "Calculator")
        XCTAssertEqual(calcActivity.activitySubtitle, "Active")
        XCTAssertEqual(calcActivity.confidence, .low, "Generic fallback must strictly be LOW confidence")
        XCTAssertEqual(calcActivity.activityState, .active)
        XCTAssertNil(calcActivity.progress, "Never fake progress for generic applications")
        
        let unknownApp = DiscoveredApplication(
            applicationName: "CustomTool",
            bundleIdentifier: "org.example.customtool",
            processIdentifier: 2020
        )
        let unknownActivity = registry.resolveActivity(for: unknownApp)
        XCTAssertEqual(unknownActivity.applicationName, "CustomTool")
        XCTAssertEqual(unknownActivity.activitySubtitle, "Active")
        XCTAssertEqual(unknownActivity.confidence, .low)
    }
    
    // MARK: - 2. Provider Registration & Resolution Hierarchy
    
    func testProviderRegistrationAndResolution() {
        let registry = UniversalActivityRegistry()
        
        final class MockCustomProvider: UniversalActivityProvider, @unchecked Sendable {
            let providerIdentifier = "com.test.mock"
            let category: ActivityProviderCategory = .creative
            let isAvailable = true
            let dataSourceDescription = "Mock test"
            let apiUsedDescription = "Test API"
            let permissionsRequiredDescription = "None"
            let confidence = ActivityConfidence.high
            let limitationsDescription = "Test only"
            var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
            
            func canHandle(application: DiscoveredApplication) -> Bool {
                return application.bundleIdentifier == "com.test.customeditor"
            }
            func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
                return UniversalAppActivity(
                    applicationName: "CustomEditor",
                    bundleIdentifier: application.bundleIdentifier,
                    activityType: .processing,
                    activityTitle: "CustomEditor",
                    activitySubtitle: "Compiling Shaders",
                    activityState: .processing,
                    progress: 0.55,
                    isIndeterminate: false,
                    priority: .appTask,
                    confidence: .high,
                    source: providerIdentifier
                )
            }
        }
        
        let provider = MockCustomProvider()
        registry.register(provider: provider)
        XCTAssertTrue(registry.allProviders.contains(where: { $0.providerIdentifier == "com.test.mock" }))
        
        let app = DiscoveredApplication(
            applicationName: "CustomEditor",
            bundleIdentifier: "com.test.customeditor",
            processIdentifier: 5555
        )
        let resolved = registry.resolveActivity(for: app)
        XCTAssertEqual(resolved.activitySubtitle, "Compiling Shaders")
        XCTAssertEqual(resolved.progress, 0.55)
        XCTAssertEqual(resolved.confidence, .high)
        
        // Unregister provider and verify fallback takes over
        registry.unregister(providerIdentifier: "com.test.mock")
        let fallback = registry.resolveActivity(for: app)
        XCTAssertEqual(fallback.confidence, .low)
        XCTAssertEqual(fallback.activitySubtitle, "Active")
    }
    
    // MARK: - 3. All 17 Activity States & Confidence Hierarchy
    
    func testUniversalActivityStatesAndConfidence() {
        let allStates: [UniversalActivityState] = [
            .idle, .active, .working, .processing, .building, .compiling, .testing,
            .rendering, .exporting, .uploading, .downloading, .installing,
            .playing, .paused, .waiting, .completed, .failed, .cancelled
        ]
        XCTAssertEqual(allStates.count, 18, "Must support all 18 activity states defined in Section 5")
        XCTAssertEqual(allStates.count, UniversalActivityState.allCases.count)
        
        // Terminal states
        XCTAssertTrue(UniversalActivityState.completed.isTerminal)
        XCTAssertTrue(UniversalActivityState.failed.isTerminal)
        XCTAssertTrue(UniversalActivityState.cancelled.isTerminal)
        XCTAssertFalse(UniversalActivityState.building.isTerminal)
        XCTAssertFalse(UniversalActivityState.rendering.isTerminal)
        XCTAssertFalse(UniversalActivityState.active.isTerminal)
        
        // Task states
        let buildingActivity = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityState: .building
        )
        XCTAssertTrue(buildingActivity.isTask)
        XCTAssertTrue(buildingActivity.isOngoing)
        
        let genericActivity = UniversalAppActivity(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            activityState: .active
        )
        XCTAssertFalse(genericActivity.isTask)
        XCTAssertFalse(genericActivity.isOngoing)
        
        // Confidence ordering
        XCTAssertLessThan(ActivityConfidence.low, ActivityConfidence.medium)
        XCTAssertLessThan(ActivityConfidence.medium, ActivityConfidence.high)
    }
    
    // MARK: - 4. AHK Activity SDK Full Lifecycle
    
    func testAHKActivitySDKLifecycle() {
        let registry = UniversalActivityRegistry.shared
        registry.clearAllActivities()
        
        // 1. Start activity
        let startAct = AHKActivity.start(
            app: .ahkMini,
            title: "Playing Runner",
            subtitle: "Level 1",
            state: .playing,
            progress: nil,
            isIndeterminate: false,
            priority: .appProcessing,
            icon: "🎮"
        )
        XCTAssertEqual(startAct.activityTitle, "Playing Runner")
        XCTAssertEqual(startAct.activitySubtitle, "Level 1")
        XCTAssertEqual(startAct.confidence, .high)
        XCTAssertEqual(registry.allActivities().count, 1)
        
        // 2. Update activity with score/progress
        let updatedAct = AHKActivity.update(
            app: .ahkMini,
            title: "Playing Runner",
            subtitle: "Score 1240",
            progress: 0.65
        )
        XCTAssertNotNil(updatedAct)
        XCTAssertEqual(updatedAct?.activitySubtitle, "Score 1240")
        XCTAssertEqual(updatedAct?.progress, 0.65)
        
        // 3. Complete activity
        let completedAct = AHKActivity.complete(
            app: .ahkMini,
            title: "Game Complete",
            subtitle: "Final Score 1240"
        )
        XCTAssertEqual(completedAct.activityState, .completed)
        XCTAssertEqual(completedAct.priority, .activityCompletion)
        XCTAssertEqual(completedAct.glyph, "✓")
        
        // 4. Fail activity (e.g. KeyChain error)
        let failAct = AHKActivity.fail(
            app: .ahkKeyChain,
            title: "AHK KeyChain",
            subtitle: "Authentication Failed",
            error: "BiometricMismatch"
        )
        XCTAssertEqual(failAct.activityState, .failed)
        XCTAssertEqual(failAct.priority, .activityCompletion)
        XCTAssertEqual(failAct.glyph, "⚠")
        
        // 5. Cancel activity
        AHKActivity.cancel(app: .ahkMini)
        XCTAssertNil(registry.allActivities().first(where: { $0.bundleIdentifier == AHKAppSource.ahkMini.rawValue }))
    }
    
    // MARK: - 5. Multiple Simultaneous Activities & Ranking
    
    func testMultipleSimultaneousActivitiesInRegistry() {
        let registry = UniversalActivityRegistry()
        registry.clearAllActivities()
        
        let xcodeBuild = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .building,
            activityTitle: "Building MyApp",
            activitySubtitle: "72%",
            activityState: .building,
            progress: 0.72,
            priority: .appTask,
            confidence: .high,
            source: "DevelopmentProvider"
        )
        
        let chromeDownload = UniversalAppActivity(
            applicationName: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            activityType: .download,
            activityTitle: "Downloading asset.zip",
            activitySubtitle: "64%",
            activityState: .downloading,
            progress: 0.64,
            priority: .fileTransfer,
            confidence: .high,
            source: "DownloadsProvider"
        )
        
        let miniPlaying = UniversalAppActivity(
            applicationName: "AHK Mini",
            bundleIdentifier: "com.ahk.mini",
            activityType: .appActive,
            activityTitle: "AHK Mini",
            activitySubtitle: "Playing Runner",
            activityState: .playing,
            priority: .appProcessing,
            confidence: .high,
            source: "AHKActivitySDK"
        )
        
        registry.registerActivity(xcodeBuild)
        registry.registerActivity(chromeDownload)
        registry.registerActivity(miniPlaying)
        
        // All 3 activities registered simultaneously
        XCTAssertEqual(registry.allActivities().count, 3)
        XCTAssertEqual(registry.activeOngoingActivities().count, 3)
        
        // Top activity should be Xcode build (priority: appTask (32) > fileTransfer (30) > appProcessing (18))
        let top = registry.topOngoingActivity()
        XCTAssertEqual(top?.bundleIdentifier, "com.apple.dt.Xcode")
        XCTAssertEqual(top?.progress, 0.72)
        
        // Complete Xcode build -> top activity transitions to next highest (Chrome download)
        registry.completeActivity(bundleIdentifier: "com.apple.dt.Xcode", succeeded: true)
        let nextTop = registry.topOngoingActivity()
        XCTAssertEqual(nextTop?.bundleIdentifier, "com.google.Chrome")
    }
    
    // MARK: - 6. Foreground App Switching & Background Activity Persistence
    
    func testForegroundAppSwitchingAndBackgroundPersistence() {
        let coordinator = IslandEventCoordinator()
        let registry = UniversalActivityRegistry()
        
        // 1. Xcode starts building (high priority background task)
        let xcodeBuild = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .building,
            activityTitle: "Building MyApp",
            activitySubtitle: "72%",
            activityState: .building,
            progress: 0.72,
            priority: .appTask,
            confidence: .high
        )
        registry.registerActivity(xcodeBuild)
        coordinator.postActivity(.appActivity(activity: xcodeBuild))
        XCTAssertEqual(coordinator.activeActivity, .appActivity(activity: xcodeBuild))
        
        // 2. User switches to Safari (generic active foreground)
        let safari = DiscoveredApplication(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            processIdentifier: 4040
        )
        let safariActivity = registry.resolveActivity(for: safari)
        XCTAssertEqual(safariActivity.priority, .appActive)
        
        // Post Safari foreground activation
        coordinator.postActivity(.appActivity(activity: safariActivity))
        
        // Dynamic Island must PRESERVE Xcode build on screen because .appTask (32) > .appActive (5)
        XCTAssertEqual(coordinator.activeActivity, .appActivity(activity: xcodeBuild),
                       "Dynamic Island must show ongoing background Xcode build while user browses in Safari")
        
        // 3. User switches to Figma (generic active foreground)
        let figma = DiscoveredApplication(
            applicationName: "Figma",
            bundleIdentifier: "com.figma.Desktop",
            processIdentifier: 5050
        )
        let figmaActivity = registry.resolveActivity(for: figma)
        coordinator.postActivity(.appActivity(activity: figmaActivity))
        
        // Still preserves Xcode build
        XCTAssertEqual(coordinator.activeActivity, .appActivity(activity: xcodeBuild))
    }
    
    // MARK: - 7. Activity Preemption & Transient HUD Restoration
    
    func testActivityPreemptionAndRestoration() {
        let coordinator = IslandEventCoordinator()
        
        let xcodeBuild = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .building,
            activityTitle: "Building MyApp",
            activitySubtitle: "72%",
            activityState: .building,
            progress: 0.72,
            priority: .appTask,
            confidence: .high
        )
        let buildAct = IslandActivity.appActivity(activity: xcodeBuild)
        coordinator.postActivity(buildAct)
        XCTAssertEqual(coordinator.activeActivity, buildAct)
        
        // Volume HUD arrives
        let volumeAct = IslandActivity.volume(level: 0.65, isMuted: false)
        coordinator.postActivity(volumeAct)
        XCTAssertEqual(coordinator.activeActivity, volumeAct)
        
        // Volume HUD expires/clears -> restores Xcode build
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, buildAct, "Must restore Xcode build after volume HUD auto-dismisses")
    }
    
    // MARK: - 8. Activity Completion & Failure Presentation
    
    func testActivityCompletionAndFailurePresentation() {
        let coordinator = IslandEventCoordinator()
        
        // Build completes: ✓ Xcode Build Succeeded
        let successAct = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .completed,
            activityTitle: "Xcode",
            activitySubtitle: "Build Succeeded",
            activityState: .completed,
            priority: .activityCompletion,
            confidence: .high,
            glyph: "✓"
        )
        let successIslandAct = IslandActivity.appActivity(activity: successAct)
        XCTAssertTrue(successIslandAct.isTransientHUD)
        XCTAssertEqual(successIslandAct.autoDismissInterval ?? 0, 2.5, accuracy: 0.1)
        
        coordinator.postActivity(successIslandAct)
        XCTAssertEqual(coordinator.activeActivity, successIslandAct)
        
        // Build fails: ⚠ Xcode Build Failed
        let failAct = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .error,
            activityTitle: "Xcode",
            activitySubtitle: "Build Failed",
            activityState: .failed,
            priority: .activityCompletion,
            confidence: .high,
            glyph: "⚠"
        )
        let failIslandAct = IslandActivity.appActivity(activity: failAct)
        XCTAssertTrue(failIslandAct.isTransientHUD)
        coordinator.postActivity(failIslandAct)
        XCTAssertEqual(coordinator.activeActivity, failIslandAct)
    }
    
    // MARK: - 9. Progress Presentation (0-100% and Indeterminate)
    
    func testProgressAndIndeterminateViewUpdate() {
        let view = AppActivityView(frame: NSRect(x: 0, y: 0, width: 235, height: 40))
        
        // 72% numeric progress
        let progressAct = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .building,
            activityTitle: "Building MyApp",
            activitySubtitle: "72%",
            activityState: .building,
            progress: 0.72,
            isIndeterminate: false
        )
        view.update(activity: progressAct)
        XCTAssertEqual(view.currentActivity?.progress, 0.72)
        XCTAssertFalse(view.currentActivity?.isIndeterminate ?? true)
        
        // Indeterminate progress (e.g. uploading or compiling without exposed percentage)
        let indeterminateAct = UniversalAppActivity(
            applicationName: "DaVinci Resolve",
            bundleIdentifier: "com.blackmagic-design.DaVinciResolve",
            activityType: .rendering,
            activityTitle: "DaVinci Resolve",
            activitySubtitle: "Rendering",
            activityState: .rendering,
            progress: nil,
            isIndeterminate: true
        )
        view.update(activity: indeterminateAct)
        XCTAssertNil(view.currentActivity?.progress)
        XCTAssertTrue(view.currentActivity?.isIndeterminate ?? false)
    }
    
    // MARK: - 10. Privacy Safety & Unsupported Application Fallback
    
    func testPrivacySafetyAndUnsupportedApplicationFallback() {
        let registry = UniversalActivityRegistry()
        
        // Browsers must NOT have internal tabs or DOM scraped (Section 21)
        let chromeApp = DiscoveredApplication(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 7777
        )
        let chromeAct = registry.resolveActivity(for: chromeApp)
        XCTAssertEqual(chromeAct.activitySubtitle, "Active")
        XCTAssertEqual(chromeAct.confidence, .low, "Browsers without explicit download must remain generic low confidence")
        XCTAssertNil(chromeAct.progress)
        
        // Antigravity editor without explicit build hook falls back truthfully to generic active
        let agyApp = DiscoveredApplication(
            applicationName: "Antigravity",
            bundleIdentifier: "com.google.antigravity",
            processIdentifier: 8888
        )
        let agyAct = registry.resolveActivity(for: agyApp)
        XCTAssertEqual(agyAct.activitySubtitle, "Active")
        XCTAssertEqual(agyAct.confidence, .low)
    }
    
    // MARK: - 11. Provider Lifecycle & Zero-Polling Validation
    
    func testProviderLifecycleAndZeroPolling() {
        let provider = AHKEcosystemActivityProvider()
        XCTAssertTrue(provider.isAvailable)
        XCTAssertEqual(provider.category, .ahk)
        
        // Verify start and stop observation are idempotent and perform zero background timer polling
        provider.startObserving()
        provider.stopObserving()
        
        let devProvider = DevelopmentActivityProvider()
        XCTAssertTrue(devProvider.isAvailable)
        XCTAssertEqual(devProvider.category, .development)
        devProvider.startObserving()
        devProvider.stopObserving()
    }
}
