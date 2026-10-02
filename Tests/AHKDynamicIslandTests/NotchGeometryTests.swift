import XCTest
@testable import AHKDynamicIslandCore

final class NotchGeometryTests: XCTestCase {
    
    func testNotchGeometryCalculationWithStandardNotch() {
        // Simulates a MacBook Pro 14" display: 1512x982 (or 1710x1112 scaled)
        let screenFrame = NSRect(x: 0, y: 0, width: 1710, height: 1112)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1650, height: 1074.5)
        let safeAreaTop: CGFloat = 37.5
        let auxLeft = NSRect(x: 0, y: 1074.5, width: 751, height: 37.5)
        let auxRight = NSRect(x: 959, y: 1074.5, width: 751, height: 37.5)
        
        let info = NotchGeometryProvider.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryLeft: auxLeft,
            auxiliaryRight: auxRight
        )
        
        XCTAssertTrue(info.hasNotch, "Should detect hardware notch")
        XCTAssertEqual(info.notchRect.width, 208, accuracy: 0.1, "Notch width should be 208 pt")
        XCTAssertEqual(info.notchRect.height, 37.5, accuracy: 0.1, "Notch height should match safeAreaTop")
        XCTAssertEqual(info.notchRect.origin.x, 751, accuracy: 0.1, "Notch X should start at auxLeft.maxX")
        XCTAssertEqual(info.notchRect.origin.y, 1112 - 37.5, accuracy: 0.1, "Notch Y should sit at top")
        XCTAssertEqual(info.anchorPoint.x, 855, accuracy: 0.1, "Anchor X should be midX of notch (855)")
        XCTAssertEqual(info.anchorPoint.y, 1112, accuracy: 0.1, "Anchor Y should be top of screen")
        
        // Collapsed bounds
        XCTAssertGreaterThanOrEqual(info.collapsedSize.width, 224, "Collapsed width should accommodate notch")
        XCTAssertEqual(info.collapsedSize.height, 42.0, accuracy: 0.1, "Collapsed height should cover notch + padding")
        XCTAssertEqual(info.collapsedFrame.maxY, 1112, accuracy: 0.1, "Collapsed island top should be flush with screen top")
        
        // Expanded bounds
        XCTAssertGreaterThanOrEqual(info.expandedSize.width, 380, "Expanded width should be at least 380 pt")
        XCTAssertEqual(info.expandedSize.height, 160, accuracy: 0.1, "Expanded height should be 160 pt")
        XCTAssertEqual(info.expandedFrame.maxY, 1112, accuracy: 0.1, "Expanded island top should be flush with screen top")
    }
    
    func testNotchDetectionWithoutAuxiliaryAreasFallback() {
        // Safe area top > 24 pt indicates notch even if auxiliary areas are not reported
        let screenFrame = NSRect(x: 0, y: 0, width: 1710, height: 1112)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1710, height: 1074)
        let safeAreaTop: CGFloat = 38.0
        
        let info = NotchGeometryProvider.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryLeft: nil,
            auxiliaryRight: nil
        )
        
        XCTAssertTrue(info.hasNotch, "Should detect notch from safeAreaTop > 24 pt")
        XCTAssertEqual(info.notchRect.height, 38.0, accuracy: 0.1)
        XCTAssertEqual(info.anchorPoint.x, screenFrame.midX, accuracy: 0.1)
    }
}
