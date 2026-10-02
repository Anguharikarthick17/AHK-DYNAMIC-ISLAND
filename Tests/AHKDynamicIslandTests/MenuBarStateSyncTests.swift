import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class MenuBarStateSyncTests: XCTestCase {
    
    func testMenuBarItemStateUpdates() {
        let menuBarController = MenuBarController()
        
        // Initial state
        menuBarController.updateVisibilityState(isVisible: true)
        menuBarController.updateExpandCollapseState(isExpanded: false)
        
        // Dynamic titles
        menuBarController.updateVisibilityState(isVisible: false)
        menuBarController.updateExpandCollapseState(isExpanded: true)
    }
    
    func testApplicationControllerCoordination() {
        let appController = ApplicationController()
        
        // Start app
        appController.start()
        XCTAssertTrue(appController.islandWindowController.stateManager.isVisible)
        
        // Toggle visibility via menu bar
        appController.menuBarDidRequestToggleVisibility()
        XCTAssertFalse(appController.islandWindowController.stateManager.isVisible)
        
        appController.menuBarDidRequestToggleVisibility()
        XCTAssertTrue(appController.islandWindowController.stateManager.isVisible)
    }
    
    func testMenuBarIconTemplateProperties() {
        let icon = MenuBarIcon.createIcon()
        XCTAssertTrue(icon.isTemplate, "Menu bar icon must be template image")
        XCTAssertEqual(icon.size.width, 18.0, accuracy: 0.1)
        XCTAssertEqual(icon.size.height, 18.0, accuracy: 0.1)
    }
}
