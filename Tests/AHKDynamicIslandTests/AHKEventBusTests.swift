import XCTest
import Foundation
@testable import AHKDynamicIslandCore

final class AHKEventBusTests: XCTestCase {
    
    func testInProcessSubscriptionAndPosting() {
        let bus = AHKEventBus()
        let expectation = expectation(description: "Receive event")
        
        bus.subscribe { event in
            XCTAssertEqual(event.source, .ahkMini)
            XCTAssertEqual(event.name, "taskStarted")
            XCTAssertEqual(event.payload["taskId"], "12345")
            expectation.fulfill()
        }
        
        let event = AHKEcosystemEvent(
            source: .ahkMini,
            name: "taskStarted",
            payload: ["taskId": "12345"]
        )
        bus.post(event)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMultipleSubscribers() {
        let bus = AHKEventBus()
        let exp1 = expectation(description: "Sub 1")
        let exp2 = expectation(description: "Sub 2")
        
        bus.subscribe { _ in exp1.fulfill() }
        bus.subscribe { _ in exp2.fulfill() }
        
        bus.post(AHKEcosystemEvent(source: .ahkKeyChain, name: "itemCopied"))
        wait(for: [exp1, exp2], timeout: 2.0)
    }
}
