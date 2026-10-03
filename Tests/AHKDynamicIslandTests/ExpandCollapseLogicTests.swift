import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class ExpandCollapseLogicTests: XCTestCase {
    
    func testImmediateExpandAndCollapse() {
        let controller = IslandWindowController()
        
        // Initial state is collapsed
        let expectedCollapsedSize = CGSize(width: DeviceIdentityManager.shared.idleCapsuleWidth, height: 26.0)
        XCTAssertEqual(controller.stateManager.currentState, .collapsed)
        XCTAssertEqual(controller.window.frame.size, expectedCollapsedSize)
        XCTAssertFalse(controller.window.allowsKeyStatus)
        
        // Non-animated immediate expand
        controller.expand(animated: false)
        XCTAssertEqual(controller.stateManager.currentState, .expanded)
        XCTAssertEqual(controller.window.frame.size, controller.currentGeometry.expandedSize)
        XCTAssertTrue(controller.window.allowsKeyStatus)
        XCTAssertTrue(controller.islandView.isExpanded)
        
        // Non-animated immediate collapse
        controller.collapse(animated: false)
        XCTAssertEqual(controller.stateManager.currentState, .collapsed)
        XCTAssertEqual(controller.window.frame.size, expectedCollapsedSize)
        XCTAssertFalse(controller.window.allowsKeyStatus)
        XCTAssertFalse(controller.islandView.isExpanded)
    }
    
    func testToggleExpandCollapse() {
        let controller = IslandWindowController()
        
        // Starts collapsed, toggle should trigger expand
        controller.toggleExpandCollapse(animated: false)
        XCTAssertEqual(controller.stateManager.currentState, .expanded)
        
        // Now expanded, toggle should trigger collapse
        controller.toggleExpandCollapse(animated: false)
        XCTAssertEqual(controller.stateManager.currentState, .collapsed)
    }
    
    func testAnimatorParameters() {
        let spring = IslandAnimator.AnimationParameters.defaultSpring
        XCTAssertEqual(spring.duration, 0.32, accuracy: 0.01)
        
        let quick = IslandAnimator.AnimationParameters.quickCollapse
        XCTAssertEqual(quick.duration, 0.26, accuracy: 0.01)
    }
}
