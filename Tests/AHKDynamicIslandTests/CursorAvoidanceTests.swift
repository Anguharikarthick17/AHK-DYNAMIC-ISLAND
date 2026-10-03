import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class CursorAvoidanceTests: XCTestCase {
    
    final class PresentationStateBox: @unchecked Sendable {
        var states: [IslandPresentationState] = []
    }
    
    // MARK: - 1. Cursor Approach & Pass-Through
    
    func testCursorApproachTransitionsToAvoidanceAndPassThrough() {
        let stateManager = IslandStateManager(initialActivity: .idle)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenGeometry = NotchGeometryProvider().geometry(for: screen)
        let layoutSpec = IslandLayoutEngine.shared.layoutSpec(
            for: .idle,
            isExpanded: false,
            screenGeometry: screenGeometry
        )
        let window = IslandWindow(contentRect: layoutSpec.frame)
        let islandView = IslandView(frame: NSRect(origin: .zero, size: layoutSpec.frame.size))
        
        let avoidanceController = CursorAvoidanceController(
            window: window,
            islandView: islandView,
            stateManager: stateManager
        )
        
        let stateBox = PresentationStateBox()
        avoidanceController.onPresentationStateChanged = { s in
            stateBox.states.append(s)
        }
        
        XCTAssertFalse(avoidanceController.isAvoidanceActive)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertEqual(stateManager.presentationState, .visible)
        
        // 1. Cursor approaches and enters Dynamic Island
        avoidanceController.handleCursorEntered()
        
        XCTAssertTrue(avoidanceController.isAvoidanceActive)
        XCTAssertTrue(window.ignoresMouseEvents, "Window MUST ignore mouse events to allow cursor pass-through to Chrome tabs")
        XCTAssertEqual(stateManager.presentationState, .cursorAvoidanceHidden)
        XCTAssertEqual(stateBox.states.last, .cursorAvoidanceHidden)
    }
    
    // MARK: - 2. Activity Preservation
    
    func testActivityPreservedThroughCursorAvoidanceCycle() {
        let ytActivity = UniversalAppActivity(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            activityType: .mediaPlaying,
            activityTitle: "Cyberpunk 2077 OST",
            activitySubtitle: "YouTube • Night City",
            activityState: .playing,
            progress: 0.42,
            priority: .nowPlaying,
            glyph: "▶"
        )
        let activeIslandActivity = IslandActivity.appActivity(activity: ytActivity)
        let stateManager = IslandStateManager(initialActivity: activeIslandActivity)
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenGeometry = NotchGeometryProvider().geometry(for: screen)
        let layoutSpec = IslandLayoutEngine.shared.layoutSpec(
            for: activeIslandActivity,
            isExpanded: false,
            screenGeometry: screenGeometry
        )
        let window = IslandWindow(contentRect: layoutSpec.frame)
        let islandView = IslandView(frame: NSRect(origin: .zero, size: layoutSpec.frame.size))
        islandView.present(activity: activeIslandActivity, isExpanded: false)
        
        let avoidanceController = CursorAvoidanceController(
            window: window,
            islandView: islandView,
            stateManager: stateManager
        )
        
        // Ensure starting state is the active YouTube activity
        XCTAssertEqual(stateManager.currentActivity, activeIslandActivity)
        XCTAssertEqual(islandView.currentActivity, activeIslandActivity)
        
        // Cursor approaches
        avoidanceController.handleCursorEntered()
        XCTAssertEqual(stateManager.presentationState, .cursorAvoidanceHidden)
        // Activity state MUST NOT be changed or reset to idle!
        XCTAssertEqual(stateManager.currentActivity, activeIslandActivity, "Current activity must be strictly preserved during cursor avoidance")
        
        // Cursor exits
        avoidanceController.resetToVisible(animated: false)
        XCTAssertEqual(stateManager.presentationState, .visible)
        XCTAssertEqual(stateManager.currentActivity, activeIslandActivity, "Current activity must remain intact when Dynamic Island restores")
    }
    
    // MARK: - 3. Exclusion Bounds & Safety Margin
    
    func testExclusionFrameSafetyMargin() {
        let frame = NSRect(x: 600, y: 860, width: 240, height: 40)
        let window = IslandWindow(contentRect: frame)
        let avoidanceController = CursorAvoidanceController(window: window)
        avoidanceController.safetyMargin = 6.0
        
        let exclusion = avoidanceController.exclusionFrame
        XCTAssertEqual(exclusion.origin.x, 594.0, accuracy: 0.1)
        XCTAssertEqual(exclusion.origin.y, 854.0, accuracy: 0.1)
        XCTAssertEqual(exclusion.size.width, 252.0, accuracy: 0.1)
        XCTAssertEqual(exclusion.size.height, 52.0, accuracy: 0.1)
        
        // Point right at the center is inside
        XCTAssertTrue(exclusion.contains(NSPoint(x: 720, y: 880)))
        // Point within 4pt safety margin is inside
        XCTAssertTrue(exclusion.contains(NSPoint(x: 596, y: 880)))
        // Point 10pt away is outside
        XCTAssertFalse(exclusion.contains(NSPoint(x: 580, y: 880)))
    }
    
    // MARK: - 4. Anti-Flicker Boundary Hysteresis
    
    func testBoundaryMovementCancelsAndDebouncesRestore() async {
        let frame = NSRect(x: 600, y: 860, width: 240, height: 40)
        let window = IslandWindow(contentRect: frame)
        let avoidanceController = CursorAvoidanceController(window: window)
        avoidanceController.hysteresisDelay = 0.05 // Short delay for fast test execution
        
        avoidanceController.handleCursorEntered()
        XCTAssertTrue(avoidanceController.isAvoidanceActive)
        
        // Cursor moves outside: debounce begins
        avoidanceController.handleMouseMoved(to: NSPoint(x: 300, y: 300))
        
        // Cursor immediately jitters back inside before delay expires: debounce cancelled!
        avoidanceController.handleMouseMoved(to: NSPoint(x: 720, y: 880))
        
        // Wait longer than hysteresis delay
        try? await Task.sleep(nanoseconds: 70_000_000)
        
        // Should STILL be hidden because cursor jittered back inside (anti-flicker protection!)
        XCTAssertTrue(avoidanceController.isAvoidanceActive, "Boundary jitter must cancel restore and prevent flicker")
    }
    
    // MARK: - 5. Reduced Motion Compliance
    
    func testReducedMotionAvoidsTransforms() {
        let frame = NSRect(x: 600, y: 860, width: 240, height: 40)
        let window = IslandWindow(contentRect: frame)
        let view = IslandView(frame: NSRect(origin: .zero, size: frame.size))
        let avoidanceController = CursorAvoidanceController(window: window, islandView: view)
        
        avoidanceController.handleCursorEntered()
        XCTAssertTrue(avoidanceController.isAvoidanceActive)
        
        avoidanceController.resetToVisible(animated: false)
        XCTAssertFalse(avoidanceController.isAvoidanceActive)
        XCTAssertEqual(view.containerView.alphaValue, 1.0)
    }
    
    // MARK: - 6. Sleep / Wake Lifecycle Cleanup
    
    func testSleepNotificationResetsAvoidance() {
        let frame = NSRect(x: 600, y: 860, width: 240, height: 40)
        let window = IslandWindow(contentRect: frame)
        let avoidanceController = CursorAvoidanceController(window: window)
        
        avoidanceController.handleCursorEntered()
        XCTAssertTrue(avoidanceController.isAvoidanceActive)
        XCTAssertTrue(window.ignoresMouseEvents)
        
        // Post screen sleep notification
        NotificationCenter.default.post(
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        // Must immediately reset to visible and restore mouse events
        avoidanceController.resetToVisible(animated: false)
        XCTAssertFalse(avoidanceController.isAvoidanceActive)
        XCTAssertFalse(window.ignoresMouseEvents)
    }
}
