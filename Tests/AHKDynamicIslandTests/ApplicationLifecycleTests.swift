import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class ApplicationLifecycleTests: XCTestCase {
    
    func testApplicationControllerInitialization() {
        let appController = ApplicationController()
        XCTAssertNotNil(appController.islandWindowController)
        XCTAssertNotNil(appController.menuBarController)
        XCTAssertNotNil(appController.performanceMonitor)
        
        // Window level must be status bar
        XCTAssertEqual(appController.islandWindowController.window.level, .statusBar)
        XCTAssertFalse(appController.islandWindowController.window.isOpaque)
        XCTAssertEqual(appController.islandWindowController.window.backgroundColor, .clear)
    }
    
    func testPerformanceMonitorSampling() {
        let monitor = PerformanceMonitor.shared
        let snapshot = monitor.sampleCurrentProcess()
        
        XCTAssertGreaterThan(snapshot.memoryUsageBytes, 0, "Process resident memory should be > 0")
        XCTAssertGreaterThan(snapshot.memoryUsageMB, 0, "Process resident memory in MB should be > 0")
        XCTAssertGreaterThanOrEqual(snapshot.cpuPercentage, 0.0, "CPU percentage should be >= 0")
        
        let desc = snapshot.description
        XCTAssertTrue(desc.contains("CPU:"), "Description should contain CPU")
        XCTAssertTrue(desc.contains("Memory:"), "Description should contain Memory")
    }
    
    func testAppDelegateTerminationCleanup() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        XCTAssertNotNil(delegate.appController)
        
        // Cleanup on terminate
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }
}
