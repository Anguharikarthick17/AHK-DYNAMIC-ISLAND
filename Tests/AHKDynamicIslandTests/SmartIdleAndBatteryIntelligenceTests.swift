import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class SmartIdleAndBatteryIntelligenceTests: XCTestCase {
    
    // MARK: - Smart Idle Information
    
    func testSmartIdlePrimaryComputerName() {
        let identity = DeviceIdentityManager.shared
        XCTAssertFalse(identity.computerName.isEmpty)
        XCTAssertGreaterThanOrEqual(identity.idleCapsuleWidth, 150.0)
    }
    
    func testSmartIdleWithSecondaryBatteryInfo() {
        let identity = DeviceIdentityManager.shared
        identity.setSecondaryInfo(nil)
        let baseName = identity.computerName
        XCTAssertEqual(identity.fullIdlePresentation, baseName)
        
        // Add charging battery info
        identity.updateSecondaryBattery(level: 0.67, isCharging: true)
        XCTAssertTrue(identity.fullIdlePresentation.contains("⚡ 67%"))
        XCTAssertTrue(identity.fullIdlePresentation.contains(baseName))
        
        // Add unplugged battery info
        identity.updateSecondaryBattery(level: 0.67, isCharging: false)
        XCTAssertTrue(identity.fullIdlePresentation.contains("• 67%"))
        
        // Clean up
        identity.setSecondaryInfo(nil)
        XCTAssertEqual(identity.fullIdlePresentation, baseName)
    }
    
    func testSmartIdleDynamicWidthAndTruncation() {
        let shortWidth = DeviceIdentityManager.calculateCapsuleWidth(for: "MY MAC")
        XCTAssertEqual(shortWidth, 150.0)
        
        let mediumWidth = DeviceIdentityManager.calculateCapsuleWidth(for: "ANGU’S MACBOOK AIR   ⚡ 67%")
        XCTAssertGreaterThanOrEqual(mediumWidth, 150.0)
        XCTAssertLessThanOrEqual(mediumWidth, 220.0)
        
        let superLong = "VERY LONG ENTERPRISE WORKSTATION MACBOOK PRO 16-INCH WITH M3 MAX AND 128GB MEMORY"
        let clampedWidth = DeviceIdentityManager.calculateCapsuleWidth(for: superLong)
        XCTAssertEqual(clampedWidth, 220.0, "Capsule width must clamp at 220 pt to avoid overflowing")
    }
    
    func testSmartIdleRestorationInView() {
        let view = IslandView(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        view.updateIdleIdentity()
        let initialText = view.idleLabel.stringValue
        
        // Interrupt with transient volume
        view.present(activity: .volume(level: 0.5, isMuted: false), isExpanded: false)
        XCTAssertTrue(view.idleView.isHidden)
        
        // Return to idle
        view.present(activity: .idle, isExpanded: false)
        XCTAssertFalse(view.idleView.isHidden)
        XCTAssertEqual(view.idleLabel.stringValue, initialText)
    }
    
    // MARK: - Battery Intelligence
    
    func testBatteryInfoLevelsAndStates() {
        // Normal battery
        let normal = BatteryInfo(level: 0.67, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(normal.level, 0.67, accuracy: 0.01)
        XCTAssertFalse(normal.isCharging)
        XCTAssertFalse(normal.isLow)
        XCTAssertFalse(normal.isCritical)
        XCTAssertFalse(normal.isFullyCharged)
        
        // Low battery (<= 20%)
        let low = BatteryInfo(level: 0.19, isCharging: false, isPluggedIn: false)
        XCTAssertTrue(low.isLow)
        XCTAssertFalse(low.isCritical)
        
        // Critical battery (<= 10%)
        let crit = BatteryInfo(level: 0.08, isCharging: false, isPluggedIn: false)
        XCTAssertTrue(crit.isLow)
        XCTAssertTrue(crit.isCritical)
        
        // Charging overrides low/critical alert state
        let chargingLow = BatteryInfo(level: 0.15, isCharging: true, isPluggedIn: true)
        XCTAssertFalse(chargingLow.isLow)
        XCTAssertFalse(chargingLow.isCritical)
        
        // Fully charged
        let full = BatteryInfo(level: 1.0, isCharging: false, isPluggedIn: true, isFullyCharged: true)
        XCTAssertTrue(full.isFullyCharged)
    }
    
    func testBatteryTimeRemainingFormatting() {
        let info = BatteryInfo(level: 0.67, isCharging: false, isPluggedIn: false, timeRemainingMinutes: 102)
        XCTAssertEqual(info.formattedTimeRemaining, "~1h 42m")
        
        let subHour = BatteryInfo(level: 0.25, isCharging: false, isPluggedIn: false, timeRemainingMinutes: 45)
        XCTAssertEqual(subHour.formattedTimeRemaining, "~45m")
        
        let invalid = BatteryInfo(level: 0.50, isCharging: false, isPluggedIn: false, timeRemainingMinutes: nil)
        XCTAssertNil(invalid.formattedTimeRemaining)
    }
    
    // MARK: - Charger Events
    
    func testChargerConnectedAndDisconnectedActivity() {
        let connected = IslandActivity.charger(isConnected: true, percent: 67)
        XCTAssertEqual(connected.priority, ActivityPriority.charger)
        XCTAssertTrue(connected.isTransientHUD)
        XCTAssertEqual(connected.autoDismissInterval, 2.5)
        
        let disconnected = IslandActivity.charger(isConnected: false, percent: 67)
        XCTAssertEqual(disconnected.priority, ActivityPriority.charger)
        XCTAssertTrue(disconnected.isTransientHUD)
        XCTAssertEqual(disconnected.autoDismissInterval, 2.5)
    }
    
    func testBatteryViewPresentation() {
        let batteryView = BatteryView(frame: NSRect(x: 0, y: 0, width: 220, height: 38))
        
        // 1. Charging
        batteryView.update(level: 0.67, isCharging: true, isLow: false, isCritical: false, timeRemaining: "~1h 42m")
        
        // 2. Fully charged
        batteryView.update(level: 1.0, isCharging: false, isLow: false, isCritical: false, isFullyCharged: true)
        
        // 3. Charger transient
        batteryView.updateCharger(isConnected: true, percent: 75)
        batteryView.updateCharger(isConnected: false, percent: 75)
    }
}
