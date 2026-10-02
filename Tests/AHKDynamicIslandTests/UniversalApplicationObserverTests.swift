import XCTest
import Foundation
@testable import AHKDynamicIslandCore

@MainActor
final class UniversalApplicationObserverTests: XCTestCase {
    
    func testObserverInitializationAndSelfExclusion() {
        let registry = UniversalActivityRegistry()
        let observer = UniversalApplicationObserver(registry: registry, selfBundleID: "com.ahk.dynamicisland")
        
        XCTAssertFalse(observer.isObserving)
        
        observer.startObserving()
        XCTAssertTrue(observer.isObserving)
        
        // Re-starting is idempotent
        observer.startObserving()
        XCTAssertTrue(observer.isObserving)
        
        observer.stopObserving()
        XCTAssertFalse(observer.isObserving)
    }
    
    func testDiscoveredApplicationModel() {
        let now = Date()
        let app = DiscoveredApplication(
            applicationName: "Antigravity",
            bundleIdentifier: "com.google.antigravity",
            processIdentifier: 1024,
            isActive: true,
            launchDate: now
        )
        
        XCTAssertEqual(app.applicationName, "Antigravity")
        XCTAssertEqual(app.bundleIdentifier, "com.google.antigravity")
        XCTAssertEqual(app.processIdentifier, 1024)
        XCTAssertTrue(app.isActive)
        XCTAssertEqual(app.launchDate, now)
    }
}
