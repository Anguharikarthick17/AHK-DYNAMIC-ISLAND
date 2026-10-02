import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class DynamicSizingTests: XCTestCase {
    
    let engine = IslandLayoutEngine.shared
    
    // Mock standard notch geometry
    let screenGeometry = NotchGeometryProvider.calculate(
        screenFrame: NSRect(x: 0, y: 0, width: 1710, height: 1112),
        visibleFrame: NSRect(x: 0, y: 0, width: 1710, height: 1074),
        safeAreaInsetsTop: 37.5,
        auxiliaryLeft: NSRect(x: 0, y: 1074.5, width: 751, height: 37.5),
        auxiliaryRight: NSRect(x: 959, y: 1074.5, width: 751, height: 37.5)
    )
    
    func testIdleStateSize() {
        let spec = engine.layoutSpec(for: .idle, isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(spec.size.width, 150.0, accuracy: 0.1)
        XCTAssertEqual(spec.size.height, 26.0, accuracy: 0.1)
        XCTAssertEqual(spec.cornerRadius, 13.0, accuracy: 0.1, "Idle capsule corner radius should be half height")
        XCTAssertEqual(spec.tier, IslandSizeTier.idle)
        
        // Frame validation: top edge pinned at 1068.0
        XCTAssertEqual(spec.frame.maxY, 1068.0, accuracy: 0.1)
        XCTAssertEqual(spec.frame.minY, 1042.0, accuracy: 0.1)
        XCTAssertEqual(spec.frame.midX, 855.0, accuracy: 0.1)
    }
    
    func testVolumeSmallEventSize() {
        let spec = engine.layoutSpec(for: .volume(level: 0.7, isMuted: false), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(spec.size.width, 210.0, accuracy: 0.1)
        XCTAssertEqual(spec.size.height, 38.0, accuracy: 0.1)
        XCTAssertEqual(spec.cornerRadius, 19.0, accuracy: 0.1)
        XCTAssertEqual(spec.tier, IslandSizeTier.smallEvent)
        XCTAssertEqual(spec.frame.maxY, 1068.0, accuracy: 0.1)
        XCTAssertEqual(spec.frame.minY, 1030.0, accuracy: 0.1)
    }
    
    func testBrightnessEventSize() {
        let spec = engine.layoutSpec(for: .brightness(level: 0.65), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(spec.size.width, 210.0, accuracy: 0.1)
        XCTAssertEqual(spec.size.height, 38.0, accuracy: 0.1)
        XCTAssertEqual(spec.cornerRadius, 19.0, accuracy: 0.1)
    }
    
    func testBatteryCriticalAlertSize() {
        let spec = engine.layoutSpec(
            for: .battery(level: 0.08, isCharging: false, isLow: true, isCritical: true),
            isExpanded: false,
            screenGeometry: screenGeometry
        )
        XCTAssertEqual(spec.tier, IslandSizeTier.mediumEvent)
        XCTAssertEqual(spec.size.width, 260.0, accuracy: 0.1)
        XCTAssertEqual(spec.size.height, 56.0, accuracy: 0.1)
    }
    
    func testNowPlayingCompactAndExpandedSize() {
        let state = NowPlayingState(title: "Song", artist: "Artist", isPlaying: true)
        
        let compactSpec = engine.layoutSpec(for: .nowPlaying(state: state), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(compactSpec.size.width, 220.0, accuracy: 0.1)
        XCTAssertEqual(compactSpec.size.height, 38.0, accuracy: 0.1)
        
        let expandedSpec = engine.layoutSpec(for: .nowPlaying(state: state), isExpanded: true, screenGeometry: screenGeometry)
        XCTAssertEqual(expandedSpec.size.width, 320.0, accuracy: 0.1)
        XCTAssertEqual(expandedSpec.size.height, 90.0, accuracy: 0.1)
        XCTAssertEqual(expandedSpec.tier, IslandSizeTier.largeEvent)
        XCTAssertEqual(expandedSpec.frame.maxY, 1068.0, accuracy: 0.1)
        XCTAssertEqual(expandedSpec.frame.minY, 978.0, accuracy: 0.1)
    }
    
    func testDownloadAndTransferSizes() {
        let dl = DownloadState(filename: "macOS_15.dmg", bytesReceived: 50, totalBytes: 100)
        let dlSpec = engine.layoutSpec(for: .download(state: dl), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(dlSpec.size.width, 270.0, accuracy: 0.1)
        XCTAssertEqual(dlSpec.size.height, 58.0, accuracy: 0.1)
        XCTAssertEqual(dlSpec.tier, IslandSizeTier.mediumEvent)
        
        let transfer = FileTransferState(filename: "Archive.zip", direction: .sending, bytesTransferred: 20, totalBytes: 100)
        let trSpec = engine.layoutSpec(for: .fileTransfer(state: transfer), isExpanded: false, screenGeometry: screenGeometry)
        XCTAssertEqual(trSpec.size.width, 270.0, accuracy: 0.1)
        XCTAssertEqual(trSpec.size.height, 58.0, accuracy: 0.1)
    }
    
    func testMaximumBoundsClamping() {
        // Even for custom requests, size must not exceed 340 x 120
        let maxDimensions = IslandSizeTier.maximum.defaultDimensions
        XCTAssertLessThanOrEqual(maxDimensions.width, 340.0)
        XCTAssertLessThanOrEqual(maxDimensions.height, 120.0)
    }
    
    func testTopEdgePreservedDuringDownwardGrowth() {
        let idleSpec = engine.layoutSpec(for: .idle, isExpanded: false, screenGeometry: screenGeometry)
        let smallSpec = engine.layoutSpec(for: .volume(level: 0.5, isMuted: false), isExpanded: false, screenGeometry: screenGeometry)
        let mediumSpec = engine.layoutSpec(for: .download(state: DownloadState(filename: "file.bin", bytesReceived: 10, totalBytes: 20)), isExpanded: false, screenGeometry: screenGeometry)
        let largeSpec = engine.layoutSpec(for: .nowPlaying(state: NowPlayingState(title: "T", artist: "A")), isExpanded: true, screenGeometry: screenGeometry)
        
        // All states must have identical top edge anchor
        XCTAssertEqual(idleSpec.frame.maxY, screenGeometry.anchorPoint.y, accuracy: 0.1)
        XCTAssertEqual(smallSpec.frame.maxY, screenGeometry.anchorPoint.y, accuracy: 0.1)
        XCTAssertEqual(mediumSpec.frame.maxY, screenGeometry.anchorPoint.y, accuracy: 0.1)
        XCTAssertEqual(largeSpec.frame.maxY, screenGeometry.anchorPoint.y, accuracy: 0.1)
        
        // Frame minY grows strictly downward
        XCTAssertGreaterThan(idleSpec.frame.minY, smallSpec.frame.minY)
        XCTAssertGreaterThan(smallSpec.frame.minY, mediumSpec.frame.minY)
        XCTAssertGreaterThan(mediumSpec.frame.minY, largeSpec.frame.minY)
    }
}
