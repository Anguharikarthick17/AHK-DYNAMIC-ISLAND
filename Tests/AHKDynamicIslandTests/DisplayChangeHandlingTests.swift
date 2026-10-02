import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class DisplayChangeHandlingTests: XCTestCase {
    
    func testDisplayObserverTriggerManualUpdate() {
        let observer = DisplayObserver(debounceInterval: 0.01)
        var triggered = false
        
        observer.startObserving {
            triggered = true
        }
        
        observer.triggerManualUpdate()
        XCTAssertTrue(triggered, "Manual update should fire change handler")
        
        observer.stopObserving()
    }
    
    func testRepositioningPreservesWindowInstance() {
        let controller = IslandWindowController()
        let initialWindow = controller.window
        
        // Trigger display change handler
        controller.handleDisplayConfigurationChanged()
        
        // Window instance should remain intact (no recreation)
        XCTAssertTrue(controller.window === initialWindow, "Window instance must be preserved across display changes")
    }
    
    func testRepositioningPreservesState() {
        let controller = IslandWindowController()
        
        // Expand
        controller.expand(animated: false)
        XCTAssertEqual(controller.stateManager.currentState, .expanded)
        
        // Trigger display change
        controller.handleDisplayConfigurationChanged()
        
        // Should still be expanded with expanded size
        XCTAssertEqual(controller.stateManager.currentState, .expanded)
        XCTAssertEqual(controller.window.frame.size, controller.currentGeometry.expandedSize)
    }
}
