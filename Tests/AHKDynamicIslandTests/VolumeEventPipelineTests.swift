import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class VolumeEventPipelineTests: XCTestCase {
    
    func testVolumeMonitorReadoutAndClamping() {
        let monitor = VolumeMonitor()
        let (volume, isMuted) = monitor.getCurrentVolume()
        XCTAssertGreaterThanOrEqual(volume, 0.0)
        XCTAssertLessThanOrEqual(volume, 1.0)
        _ = isMuted // Boolean check
        
        XCTAssertEqual(VolumeMonitor.clampVolume(-0.5), 0.0)
        XCTAssertEqual(VolumeMonitor.clampVolume(1.5), 1.0)
        XCTAssertEqual(VolumeMonitor.clampVolume(0.72), 0.72, accuracy: 0.001)
    }
    
    func testCompleteVolumeEventPipeline() {
        let coordinator = IslandEventCoordinator()
        let windowController = IslandWindowController()
        
        var coordinatorReceivedActivity: IslandActivity?
        coordinator.onActivityChanged = { activity in
            coordinatorReceivedActivity = activity
            windowController.presentActivity(activity, isExpanded: false, animated: false)
        }
        
        // 1. Initial State: Idle capsule
        XCTAssertEqual(coordinator.activeActivity, .idle)
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 150.0, height: 26.0))
        
        // 2. Inject VolumeEvent(level: 0.72, muted: false)
        let volumeActivity = IslandActivity.volume(level: 0.72, isMuted: false)
        coordinator.postActivity(volumeActivity)
        
        // Verify Coordinator receives and presents
        XCTAssertEqual(coordinator.activeActivity, volumeActivity)
        XCTAssertEqual(coordinatorReceivedActivity, volumeActivity)
        
        // Verify WindowController expands to small event tier (210 x 38 pt)
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 210.0, height: 38.0))
        XCTAssertEqual(windowController.window.frame.maxY, windowController.currentGeometry.anchorPoint.y, accuracy: 0.1)
        
        // Verify IslandView receives volume state and updates subview
        XCTAssertEqual(windowController.islandView.currentActivity, volumeActivity)
        XCTAssertFalse(windowController.islandView.volumeView.isHidden)
        
        // 3. Verify Auto-Dismiss Interval is 1.8 seconds
        XCTAssertEqual(volumeActivity.autoDismissInterval ?? 0, 1.8, accuracy: 0.01)
        
        // 4. Dismissal restores idle (150 x 26 pt)
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 150.0, height: 26.0))
    }
}
