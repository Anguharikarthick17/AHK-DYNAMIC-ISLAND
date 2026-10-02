import XCTest
@testable import AHKDynamicIslandCore

final class IslandStateTests: XCTestCase {
    
    func testInitialState() {
        let manager = IslandStateManager()
        XCTAssertEqual(manager.currentState, .collapsed)
        XCTAssertTrue(manager.isVisible)
        XCTAssertTrue(manager.currentState.canExpand)
        XCTAssertFalse(manager.currentState.canCollapse)
        XCTAssertFalse(manager.currentState.isExpandedOrExpanding)
        XCTAssertTrue(manager.currentState.isCollapsedOrCollapsing)
    }
    
    func testStandardExpandCollapseCycle() {
        let manager = IslandStateManager()
        
        var recordedStates: [IslandDisplayState] = []
        manager.onStateChanged = { state in
            recordedStates.append(state)
        }
        
        // Collapsed -> Expanding
        XCTAssertTrue(manager.transition(to: .expanding))
        XCTAssertEqual(manager.currentState, .expanding)
        XCTAssertTrue(manager.currentState.isExpandedOrExpanding)
        
        // Expanding -> Expanded
        XCTAssertTrue(manager.transition(to: .expanded))
        XCTAssertEqual(manager.currentState, .expanded)
        XCTAssertTrue(manager.currentState.canCollapse)
        XCTAssertFalse(manager.currentState.canExpand)
        
        // Expanded -> Collapsing
        XCTAssertTrue(manager.transition(to: .collapsing))
        XCTAssertEqual(manager.currentState, .collapsing)
        XCTAssertTrue(manager.currentState.isCollapsedOrCollapsing)
        
        // Collapsing -> Collapsed
        XCTAssertTrue(manager.transition(to: .collapsed))
        XCTAssertEqual(manager.currentState, .collapsed)
        
        XCTAssertEqual(recordedStates, [.expanding, .expanded, .collapsing, .collapsed])
    }
    
    func testInterruptionHandling() {
        let manager = IslandStateManager()
        
        // Start expanding
        manager.transition(to: .expanding)
        XCTAssertEqual(manager.currentState, .expanding)
        
        // User clicks to collapse in the middle of expanding (interruption)
        XCTAssertTrue(manager.transition(to: .collapsing), "Should allow collapsing interruption while expanding")
        XCTAssertEqual(manager.currentState, .collapsing)
        
        // User immediately clicks to expand again before collapse finished
        XCTAssertTrue(manager.transition(to: .expanding), "Should allow expanding interruption while collapsing")
        XCTAssertEqual(manager.currentState, .expanding)
    }
    
    func testToggledTargetState() {
        let manager = IslandStateManager()
        XCTAssertEqual(manager.toggledTargetState, .expanded)
        
        manager.transition(to: .expanded)
        XCTAssertEqual(manager.toggledTargetState, .collapsed)
        
        manager.transition(to: .collapsing)
        XCTAssertEqual(manager.toggledTargetState, .expanded)
        
        manager.transition(to: .expanding)
        XCTAssertEqual(manager.toggledTargetState, .collapsed)
    }
    
    func testVisibilityToggle() {
        let manager = IslandStateManager()
        XCTAssertTrue(manager.isVisible)
        
        var recordedVisibility: [Bool] = []
        manager.onVisibilityChanged = { visible in
            recordedVisibility.append(visible)
        }
        
        manager.toggleVisibility()
        XCTAssertFalse(manager.isVisible)
        
        manager.toggleVisibility()
        XCTAssertTrue(manager.isVisible)
        
        XCTAssertEqual(recordedVisibility, [false, true])
    }
}
