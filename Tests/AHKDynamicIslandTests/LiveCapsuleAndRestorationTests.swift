import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class LiveCapsuleAndRestorationTests: XCTestCase {
    
    func testPersistentIdleIdentityDynamicComputerName() {
        let view = IslandView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        
        let expectedName = DeviceIdentityManager.shared.computerName
        XCTAssertEqual(view.idleLabel.stringValue, expectedName)
        XCTAssertNotEqual(view.idleLabel.stringValue, "AHK MAC", "Hardcoded 'AHK MAC' must not remain as the idle identity")
        XCTAssertEqual(view.idleLabel.alignment, .center)
        XCTAssertFalse(view.idleLabel.isEditable)
    }
    
    func testDynamicCapsuleSizingTiers() {
        let layoutEngine = IslandLayoutEngine.shared
        let dummyScreen = NSScreen.main ?? NSScreen.screens[0]
        let geometry = NotchGeometryProvider().geometry(for: dummyScreen)
        
        // 1. Idle state (Dynamic Computer Name)
        let expectedIdleWidth = DeviceIdentityManager.shared.idleCapsuleWidth
        let idleSpec = layoutEngine.layoutSpec(for: .idle, isExpanded: false, screenGeometry: geometry)
        XCTAssertEqual(idleSpec.size, CGSize(width: expectedIdleWidth, height: 26.0))
        XCTAssertEqual(idleSpec.cornerRadius, 13.0)
        
        // 2. Generic App Activity
        let genericApp = UniversalAppActivity(applicationName: "Figma", bundleIdentifier: "com.figma.Desktop", activityType: .appActive)
        let appSpec = layoutEngine.layoutSpec(for: .appActivity(activity: genericApp), isExpanded: false, screenGeometry: geometry)
        XCTAssertEqual(appSpec.size, CGSize(width: 210.0, height: 38.0))
        XCTAssertEqual(appSpec.cornerRadius, 19.0)
        
        // 3. Ongoing App Activity (Building)
        let buildApp = UniversalAppActivity(applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", activityType: .building, stateText: "Building", priority: .appProcessing)
        let buildSpec = layoutEngine.layoutSpec(for: .appActivity(activity: buildApp), isExpanded: false, screenGeometry: geometry)
        XCTAssertEqual(buildSpec.size, CGSize(width: 235.0, height: 40.0))
        XCTAssertEqual(buildSpec.cornerRadius, 20.0)
        
        // 4. Expanded App Activity
        let expandedSpec = layoutEngine.layoutSpec(for: .appActivity(activity: genericApp), isExpanded: true, screenGeometry: geometry)
        XCTAssertEqual(expandedSpec.size, CGSize(width: 310.0, height: 86.0))
    }
    
    func testAppActivityPreemptionAndRestorationPipeline() {
        let coordinator = IslandEventCoordinator()
        
        // 1. Initially idle (dynamic device identity)
        XCTAssertEqual(coordinator.activeActivity, .idle)
        
        // 2. App activation occurs: Terminal • Active
        let termActivity = UniversalAppActivity(
            applicationName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            activityType: .appActive,
            stateText: "Active",
            priority: .appActive,
            glyph: "⌘"
        )
        let appAct = IslandActivity.appActivity(activity: termActivity)
        coordinator.postActivity(appAct)
        XCTAssertEqual(coordinator.activeActivity, appAct)
        
        // 3. Transient volume HUD interrupts
        let volumeAct = IslandActivity.volume(level: 0.72, isMuted: false)
        coordinator.postActivity(volumeAct)
        XCTAssertEqual(coordinator.activeActivity, volumeAct)
        
        // 4. Transient volume auto-dismisses -> restores Terminal • Active
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, appAct)
        
        // 5. App deactivates / completes -> restores idle dynamic identity
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }
    
    func testOngoingBuildPreemptionAndRestoration() {
        let coordinator = IslandEventCoordinator()
        
        // 1. Xcode builds: ongoing activity
        let xcodeBuild = UniversalAppActivity(
            applicationName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            activityType: .building,
            stateText: "Building",
            priority: .appProcessing,
            glyph: "⚒"
        )
        let buildAct = IslandActivity.appActivity(activity: xcodeBuild)
        coordinator.postActivity(buildAct)
        XCTAssertEqual(coordinator.activeActivity, buildAct)
        
        // 2. Volume adjustment occurs
        let volAct = IslandActivity.volume(level: 0.65, isMuted: false)
        coordinator.postActivity(volAct)
        XCTAssertEqual(coordinator.activeActivity, volAct)
        
        // 3. Volume HUD auto-dismisses -> restores Xcode build
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, buildAct)
        
        // 4. Build finishes
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }
}
