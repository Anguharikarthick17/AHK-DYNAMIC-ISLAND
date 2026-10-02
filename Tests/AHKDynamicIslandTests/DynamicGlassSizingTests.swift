import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class DynamicGlassSizingTests: XCTestCase {
    
    let engine = IslandLayoutEngine.shared
    let screenGeometry = NotchGeometryProvider.calculate(
        screenFrame: NSRect(x: 0, y: 0, width: 1710, height: 1112),
        visibleFrame: NSRect(x: 0, y: 0, width: 1710, height: 1074),
        safeAreaInsetsTop: 37.5,
        auxiliaryLeft: NSRect(x: 0, y: 1074.5, width: 751, height: 37.5),
        auxiliaryRight: NSRect(x: 959, y: 1074.5, width: 751, height: 37.5)
    )
    
    func testContentMarginsAcrossTiers() {
        let idleSpec = engine.layoutSpec(for: .idle, isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertGreaterThanOrEqual(idleSpec.contentInsets.left, 8.0)
        XCTAssertLessThanOrEqual(idleSpec.contentInsets.left, 12.0)
        
        let smallSpec = engine.layoutSpec(for: .volume(level: 0.5, isMuted: false), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertGreaterThanOrEqual(smallSpec.contentInsets.left, 10.0)
        XCTAssertLessThanOrEqual(smallSpec.contentInsets.left, 14.0)
        
        let mediumSpec = engine.layoutSpec(for: .download(state: DownloadState(filename: "f", bytesReceived: 1, totalBytes: 2)), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertGreaterThanOrEqual(mediumSpec.contentInsets.left, 12.0)
        XCTAssertLessThanOrEqual(mediumSpec.contentInsets.left, 18.0)
        
        let largeSpec = engine.layoutSpec(for: .nowPlaying(state: NowPlayingState(title: "T", artist: "A")), isExpanded: true, screenGeometry: screenGeometry)
        XCTAssertGreaterThanOrEqual(largeSpec.contentInsets.left, 14.0)
        XCTAssertLessThanOrEqual(largeSpec.contentInsets.left, 20.0)
    }
    
    func testGlassAdaptiveCornerRadii() {
        let idleSpec = engine.layoutSpec(for: .idle, isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(idleSpec.cornerRadius, 13.0, accuracy: 0.1)
        
        let smallSpec = engine.layoutSpec(for: .volume(level: 0.5, isMuted: false), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(smallSpec.cornerRadius, 19.0, accuracy: 0.1)
        
        let largeSpec = engine.layoutSpec(for: .nowPlaying(state: NowPlayingState(title: "T", artist: "A")), isExpanded: true, screenGeometry: screenGeometry)
        XCTAssertEqual(largeSpec.cornerRadius, 26.0, accuracy: 0.1)
    }
}
