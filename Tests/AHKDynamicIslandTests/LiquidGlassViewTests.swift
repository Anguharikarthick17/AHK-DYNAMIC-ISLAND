import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class LiquidGlassViewTests: XCTestCase {
    
    func testLiquidGlassContainerInitialization() {
        let glassView = LiquidGlassContainerView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        XCTAssertNotNil(glassView.contentView)
        XCTAssertEqual(glassView.cornerRadius, 13.0, accuracy: 0.1)
        XCTAssertFalse(glassView.isInteractive, "Default state should be non-interactive")
    }
    
    func testInteractivityToggle() {
        let glassView = LiquidGlassContainerView(frame: NSRect(x: 0, y: 0, width: 320, height: 90))
        glassView.isInteractive = true
        XCTAssertTrue(glassView.isInteractive)
        
        glassView.isInteractive = false
        XCTAssertFalse(glassView.isInteractive)
    }
    
    func testCornerRadiusUpdate() {
        let glassView = LiquidGlassContainerView(frame: NSRect(x: 0, y: 0, width: 210, height: 38))
        glassView.cornerRadius = 19.0
        XCTAssertEqual(glassView.cornerRadius, 19.0, accuracy: 0.1)
    }
    
    func testIslandViewGlassIntegration() {
        let islandView = IslandView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        XCTAssertNotNil(islandView.glassContainer)
        
        // Idle presentation
        islandView.present(activity: .idle, isExpanded: false)
        XCTAssertFalse(islandView.glassContainer.isInteractive, "Idle island glass must not be interactive")
        
        // Media presentation with interactive controls
        islandView.present(activity: .nowPlaying(state: NowPlayingState(title: "Track", artist: "Artist")), isExpanded: true)
        XCTAssertTrue(islandView.glassContainer.isInteractive, "Music island glass must enable interactivity for controls")
    }
}
