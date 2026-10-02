import XCTest
import AppKit
@testable import AHKDynamicIslandCore

private final class TestLevelBox: @unchecked Sendable {
    var value: Float = 0.0
}

@MainActor
final class BrightnessEventSourceTests: XCTestCase {
    
    func testHardwareBrightnessBoundaryReport() {
        // Must explicitly document that hardware brightness via public APIs on sandboxed macOS is unsupported
        XCTAssertFalse(
            PublicBrightnessEventSource.isHardwareBrightnessSupported,
            "Public APIs do not support internal panel backlight access on Apple Silicon"
        )
    }
    
    func testBrightnessEventSourceLifecycle() {
        let source = PublicBrightnessEventSource()
        source.start()
        source.stop()
    }
    
    func testTestBrightnessInjection() {
        let monitor = BrightnessMonitor()
        let expectation = expectation(description: "Brightness event received")
        let box = TestLevelBox()
        
        monitor.onBrightnessChanged = { level in
            box.value = level
            expectation.fulfill()
        }
        
        monitor.setBrightness(level: 0.68)
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(box.value, 0.68, accuracy: 0.01)
    }
    
    func testClamping() {
        let monitor = BrightnessMonitor()
        let exp = expectation(description: "Clamp high")
        let box = TestLevelBox()
        
        monitor.onBrightnessChanged = { level in
            box.value = level
            exp.fulfill()
        }
        monitor.setBrightness(level: 1.5)
        wait(for: [exp], timeout: 1.0)
        
        XCTAssertEqual(box.value, 1.0, accuracy: 0.01)
    }
}
