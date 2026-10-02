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
        let gap: CGFloat = 6.0
        
        let info = NotchGeometryProvider.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryLeft: auxLeft,
            auxiliaryRight: auxRight,
            gap: gap
        )
        
        XCTAssertTrue(info.hasNotch, "Should detect hardware notch")
        XCTAssertEqual(info.notchRect.width, 208, accuracy: 0.1, "Notch width should be 208 pt")
        XCTAssertEqual(info.notchRect.height, 37.5, accuracy: 0.1, "Notch height should match safeAreaTop")
        XCTAssertEqual(info.notchRect.origin.x, 751, accuracy: 0.1, "Notch X should start at auxLeft.maxX")
        XCTAssertEqual(info.notchRect.origin.y, 1112 - 37.5, accuracy: 0.1, "Notch Y should sit at 1074.5")
        
        // Notch bottom edge calculation
        XCTAssertEqual(info.notchBottomY, 1074.5, accuracy: 0.1, "Notch bottom Y must be 1074.5 pt")
        XCTAssertEqual(info.gap, 6.0, accuracy: 0.1, "Gap between notch and island must be 6 pt")
        
        // Anchor point: Centered horizontally at notch midX, top at notchBottomY - gap (rounded down to integer point)
        let expectedIslandTopY: CGFloat = (1074.5 - 6.0).rounded(.down) // 1068.0 pt
        XCTAssertEqual(info.anchorPoint.x, 855.0, accuracy: 0.1, "Anchor X should be midX of notch (855)")
        XCTAssertEqual(info.anchorPoint.y, expectedIslandTopY, accuracy: 0.1, "Anchor Y must be directly below notch")
        
        // CRITICAL: Island top edge must be strictly below notch bottom edge
        
        // Collapsed bounds (150 x 26 pt)
        XCTAssertEqual(info.collapsedSize.width, 150.0, accuracy: 0.1)
        XCTAssertEqual(info.collapsedSize.height, 26.0, accuracy: 0.1)
        XCTAssertEqual(info.collapsedFrame.maxY, expectedIslandTopY, accuracy: 0.1, "Collapsed island top must be 6pt below notch")
        XCTAssertLessThan(info.collapsedFrame.maxY, info.notchBottomY, "Collapsed island must be completely below notch")
        
        // Expanded bounds (340 x 90 pt)
        XCTAssertEqual(info.expandedSize.width, 340.0, accuracy: 0.1)
        XCTAssertEqual(info.expandedSize.height, 90.0, accuracy: 0.1)
        XCTAssertEqual(info.expandedFrame.maxY, expectedIslandTopY, accuracy: 0.1, "Expanded island top must stay 6pt below notch")
        XCTAssertLessThan(info.expandedFrame.maxY, info.notchBottomY, "Expanded island must never expand behind the notch")
        
        // Expansion is downward only
        XCTAssertEqual(info.expandedFrame.minY, expectedIslandTopY - 90.0, accuracy: 0.1)
        XCTAssertLessThan(info.expandedFrame.minY, info.collapsedFrame.minY, "Expanded island grows downward")
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
        XCTAssertEqual(info.notchBottomY, 1112 - 38.0, accuracy: 0.1)
        XCTAssertLessThan(info.collapsedFrame.maxY, info.notchBottomY)
    }
}
