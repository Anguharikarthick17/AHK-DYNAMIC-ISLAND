import XCTest
@testable import AHKDynamicIslandCore

final class NonNotchFallbackTests: XCTestCase {
    
    func testNonNotchDisplayWithStandardMenuBar() {
        // Simulates an external 4K monitor (3840x2160 or 1920x1080 scaled) with 24pt menu bar
        let screenFrame = NSRect(x: 0, y: 0, width: 2560, height: 1440)
        let visibleFrame = NSRect(x: 0, y: 0, width: 2560, height: 1416) // Menu bar height 24 pt
        let safeAreaTop: CGFloat = 0.0
        
        let info = NotchGeometryProvider.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryLeft: nil,
            auxiliaryRight: nil
        )
        
        XCTAssertFalse(info.hasNotch, "External screen should not report a notch")
        XCTAssertEqual(info.notchRect, NSRect.zero, "Notch rect should be zero")
        XCTAssertEqual(info.menuBarHeight, 24.0, accuracy: 0.1, "Menu bar height should be 24 pt")
        XCTAssertEqual(info.anchorPoint.x, 1280.0, accuracy: 0.1, "Anchor X should be centered at screen.midX")
        
        // Ensure the island is positioned below the menu bar with safety margin
        XCTAssertLessThanOrEqual(info.collapsedFrame.maxY, visibleFrame.maxY, "Collapsed island must not cover the menu bar")
        XCTAssertLessThanOrEqual(info.expandedFrame.maxY, visibleFrame.maxY, "Expanded island must not cover the menu bar")
        
        // Dimensions
        XCTAssertEqual(info.collapsedSize.width, 180.0, accuracy: 0.1)
        XCTAssertEqual(info.collapsedSize.height, 34.0, accuracy: 0.1)
        XCTAssertEqual(info.expandedSize.width, 360.0, accuracy: 0.1)
        XCTAssertEqual(info.expandedSize.height, 140.0, accuracy: 0.1)
    }
    
    func testNonNotchDisplayWithAutoHiddenMenuBar() {
        // Menu bar is auto-hidden, so visibleFrame.maxY == screenFrame.maxY
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let safeAreaTop: CGFloat = 0.0
        
        let info = NotchGeometryProvider.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryLeft: nil,
            auxiliaryRight: nil
        )
        
        XCTAssertFalse(info.hasNotch)
        // With auto-hidden menu bar, anchor should sit slightly below top edge with safe margin
        XCTAssertLessThanOrEqual(info.anchorPoint.y, screenFrame.maxY - 4.0)
        XCTAssertEqual(info.anchorPoint.x, 960.0, accuracy: 0.1)
    }
    
    func testSecondaryMonitorWithNonZeroOrigin() {
        // Multi-display setup: external monitor positioned to the right of primary
        let screenFrame = NSRect(x: 1710, y: 200, width: 2560, height: 1440)
        let visibleFrame = NSRect(x: 1710, y: 200, width: 2560, height: 1416)
        
        let info = NotchGeometryProvider.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: 0,
            auxiliaryLeft: nil,
            auxiliaryRight: nil
        )
        
        XCTAssertEqual(info.anchorPoint.x, 1710 + 1280.0, accuracy: 0.1)
        XCTAssertEqual(info.collapsedFrame.origin.x, 1710 + 1280.0 - 90.0, accuracy: 0.1)
    }
}
