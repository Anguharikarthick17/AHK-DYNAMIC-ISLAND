import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class DeviceIdentityTests: XCTestCase {
    
    // MARK: - 1. Computer Name Successfully Resolved
    func testComputerNameSuccessfullyResolved() {
        let name = DeviceIdentityManager.shared.computerName
        XCTAssertFalse(name.isEmpty, "Device computer name must not be empty")
        XCTAssertGreaterThanOrEqual(name.count, 2)
        XCTAssertGreaterThanOrEqual(DeviceIdentityManager.shared.idleCapsuleWidth, 150.0)
    }
    
    // MARK: - 2. Localized Computer Name
    func testLocalizedComputerNameResolution() {
        let name1 = DeviceIdentityManager.resolve(localizedName: "John's MacBook Pro", hostName: "johns-mbp.local")
        XCTAssertEqual(name1, "JOHN'S MACBOOK PRO")
        
        let name2 = DeviceIdentityManager.resolve(localizedName: "Angu’s MacBook Air", hostName: "Angus-Air.local")
        XCTAssertEqual(name2, "ANGU’S MACBOOK AIR")
    }
    
    // MARK: - 3. Hostname Fallback
    func testHostnameFallback() {
        // When localizedName is nil
        let fallback1 = DeviceIdentityManager.resolve(localizedName: nil, hostName: "macbook-air.local")
        XCTAssertEqual(fallback1, "MACBOOK-AIR")
        
        // When localizedName is whitespace
        let fallback2 = DeviceIdentityManager.resolve(localizedName: "   ", hostName: "studio-display-mac.local")
        XCTAssertEqual(fallback2, "STUDIO-DISPLAY-MAC")
    }
    
    // MARK: - 4. Unavailable Name Fallback
    func testUnavailableNameFallback() {
        // Both nil
        let fallback1 = DeviceIdentityManager.resolve(localizedName: nil, hostName: nil)
        XCTAssertEqual(fallback1, "THIS MAC")
        
        // Localized empty, host is localhost
        let fallback2 = DeviceIdentityManager.resolve(localizedName: "", hostName: "localhost")
        XCTAssertEqual(fallback2, "THIS MAC")
        
        // Both whitespace
        let fallback3 = DeviceIdentityManager.resolve(localizedName: "   ", hostName: "   ")
        XCTAssertEqual(fallback3, "THIS MAC")
    }
    
    // MARK: - 5. Long Computer Name Truncation & Capsule Width Clamping
    func testLongComputerNameTruncation() {
        let superLongName = "ANGU'S MACBOOK PRO 16-INCH WITH M3 MAX AND 128GB UNIFIED MEMORY"
        let width = DeviceIdentityManager.calculateCapsuleWidth(for: superLongName)
        
        // Sizing must be clamped to max 220.0 pt to prevent oversized capsule
        XCTAssertLessThanOrEqual(width, 220.0)
        XCTAssertGreaterThanOrEqual(width, 150.0)
        
        // Verify view setup: lineBreakMode is truncating tail and compression resistance is set
        let view = IslandView(frame: NSRect(x: 0, y: 0, width: width, height: 26))
        view.updateIdleIdentity(name: superLongName)
        XCTAssertEqual(view.idleLabel.lineBreakMode, .byTruncatingTail)
    }
    
    // MARK: - 6. Short Computer Name Minimum Sizing
    func testShortComputerNameMinimumSizing() {
        let shortName = "MY MAC"
        let width = DeviceIdentityManager.calculateCapsuleWidth(for: shortName)
        XCTAssertEqual(width, 150.0, "Short computer names must adhere to the 150 pt minimum capsule width")
    }
    
    // MARK: - 7. Idle State Displays Dynamic Name
    func testIdleStateDisplaysDynamicName() {
        let view = IslandView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        let currentResolvedName = DeviceIdentityManager.shared.computerName
        XCTAssertEqual(view.idleLabel.stringValue, currentResolvedName)
    }
    
    // MARK: - 8. Activity -> Idle Restores Dynamic Name
    func testActivityToIdleRestoresDynamicName() {
        let view = IslandView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        let initialName = DeviceIdentityManager.shared.computerName
        
        // Present volume activity
        view.present(activity: .volume(level: 0.72, isMuted: false), isExpanded: false)
        XCTAssertFalse(view.volumeView.isHidden)
        XCTAssertTrue(view.idleView.isHidden)
        
        // Return to idle
        view.present(activity: .idle, isExpanded: false)
        XCTAssertFalse(view.idleView.isHidden)
        XCTAssertTrue(view.volumeView.isHidden)
        XCTAssertEqual(view.idleLabel.stringValue, initialName)
    }
    
    // MARK: - 9. No Hardcoded "AHK MAC" Remains as Primary Idle Identity
    func testNoHardcodedAHKMACRemainsAsPrimaryIdleIdentity() {
        let name = DeviceIdentityManager.shared.computerName
        XCTAssertNotEqual(name, "AHK MAC", "Primary identity must be dynamically resolved, not hardcoded 'AHK MAC'")
        
        let view = IslandView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        XCTAssertNotEqual(view.idleLabel.stringValue, "AHK MAC")
    }
    
    // MARK: - 10. No Hardcoded Developer Computer Name
    func testNoHardcodedDeveloperComputerName() {
        // Verify that if a different Mac runs this code, it does not default to any hardcoded developer name
        let resolved = DeviceIdentityManager.resolve(localizedName: "Alice's MacBook Pro", hostName: "alices-mbp.local")
        XCTAssertEqual(resolved, "ALICE'S MACBOOK PRO")
        
        let genericFallback = DeviceIdentityManager.resolve(localizedName: nil, hostName: nil)
        XCTAssertEqual(genericFallback, "THIS MAC")
    }
}
