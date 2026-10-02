import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class EventToWindowExpansionTests: XCTestCase {
    
    func testIdleToVolumeExpansionAndCollapse() {
        let coordinator = IslandEventCoordinator()
        let windowController = IslandWindowController()
        
        coordinator.onActivityChanged = { act in
            windowController.presentActivity(act, isExpanded: false, animated: false)
        }
        
        // 1. Initially 150 x 26
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 150.0, height: 26.0))
        
        // 2. Post volume -> 210 x 38
        coordinator.postActivity(.volume(level: 0.5, isMuted: false))
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 210.0, height: 38.0))
        XCTAssertEqual(windowController.window.frame.maxY, windowController.currentGeometry.anchorPoint.y, accuracy: 0.1)
        
        // 3. Clear -> returns to 150 x 26
        coordinator.clearCurrentActivity()
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 150.0, height: 26.0))
    }
    
    func testIdleToNowPlayingExpanded() {
        let coordinator = IslandEventCoordinator()
        let windowController = IslandWindowController()
        
        coordinator.onActivityChanged = { act in
            windowController.presentActivity(act, isExpanded: true, animated: false)
        }
        
        coordinator.postActivity(.nowPlaying(state: NowPlayingState(title: "Track", artist: "Artist")))
        XCTAssertEqual(windowController.window.frame.size, CGSize(width: 320.0, height: 90.0))
        XCTAssertEqual(windowController.window.frame.maxY, windowController.currentGeometry.anchorPoint.y, accuracy: 0.1)
    }
}
