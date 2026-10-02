import XCTest
import Foundation
@testable import AHKDynamicIslandCore

@MainActor
final class UniversalActivityTests: XCTestCase {
    
    func testUniversalAppActivityModelAndConfidence() {
        let genericApp = UniversalAppActivity(
            applicationName: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            activityType: .appActive,
            stateText: "Active",
            confidence: .low
        )
        
        XCTAssertEqual(genericApp.applicationName, "Calculator")
        XCTAssertEqual(genericApp.confidence, .low)
        XCTAssertEqual(genericApp.confidence.displayName, "Generic Identity")
        XCTAssertEqual(genericApp.formattedTitle, "● Calculator • Active")
        XCTAssertFalse(genericApp.activityType.isOngoing)
    }
    
    func testCategoryGlyphResolution() {
        // Terminal
        let termGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "Terminal", bundleIdentifier: "com.apple.Terminal", activityType: .appActive)
        XCTAssertEqual(termGlyph, "⌘")
        
        // Developer
        let xcodeGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", activityType: .appActive)
        XCTAssertEqual(xcodeGlyph, "⚒")
        
        let antiGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "Antigravity", bundleIdentifier: "com.google.antigravity", activityType: .appActive)
        XCTAssertEqual(antiGlyph, "✦")
        
        // Creative
        let figmaGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "Figma", bundleIdentifier: "com.figma.Desktop", activityType: .appActive)
        XCTAssertEqual(figmaGlyph, "◇")
        
        // Communication
        let discordGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "Discord", bundleIdentifier: "com.hnc.Discord", activityType: .appActive)
        XCTAssertEqual(discordGlyph, "◉")
        
        // Web Browsers
        let safariGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "Safari", bundleIdentifier: "com.apple.Safari", activityType: .appActive)
        XCTAssertEqual(safariGlyph, "🌐")
        
        // AHK Ecosystem
        let ahkMiniGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "AHK Mini", bundleIdentifier: "com.ahk.mini", activityType: .appActive)
        XCTAssertEqual(ahkMiniGlyph, "🎮")
        
        // Arbitrary unknown app
        let unknownGlyph = UniversalAppActivity.resolveCategoryGlyph(applicationName: "QuantumSynthesizer", bundleIdentifier: "com.audio.quantum", activityType: .appActive)
        XCTAssertEqual(unknownGlyph, "●")
    }
    
    func testGenericFallbackProvider() {
        let genericProvider = GenericAppActivityProvider()
        let unknownApp = DiscoveredApplication(
            applicationName: "TotallyUnanticipatedApp",
            bundleIdentifier: "org.future.software.app",
            processIdentifier: 4567
        )
        
        XCTAssertTrue(genericProvider.canHandle(application: unknownApp))
        let resolved = genericProvider.resolveActivity(for: unknownApp)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.applicationName, "TotallyUnanticipatedApp")
        XCTAssertEqual(resolved?.confidence, .low)
        XCTAssertEqual(resolved?.priority, .appActive)
        XCTAssertEqual(resolved?.stateText, "Active")
    }
    
    func testUniversalActivityRegistryResolution() {
        let registry = UniversalActivityRegistry()
        
        // 1. Generic resolution of unanticipated application
        let novelApp = DiscoveredApplication(
            applicationName: "NovaEditor",
            bundleIdentifier: "com.panic.Nova",
            processIdentifier: 1234
        )
        let resolvedNovel = registry.resolveActivity(for: novelApp)
        XCTAssertEqual(resolvedNovel.applicationName, "NovaEditor")
        XCTAssertEqual(resolvedNovel.confidence, .low)
        XCTAssertEqual(resolvedNovel.stateText, "Active")
        
        // 2. Specialized ecosystem resolution for AHK Mini
        let ahkMiniApp = DiscoveredApplication(
            applicationName: "AHK Mini",
            bundleIdentifier: "com.ahk.mini",
            processIdentifier: 9999
        )
        let resolvedMini = registry.resolveActivity(for: ahkMiniApp)
        XCTAssertEqual(resolvedMini.applicationName, "AHK Mini")
        XCTAssertEqual(resolvedMini.confidence, .high)
        XCTAssertEqual(resolvedMini.glyph, "🎮")
    }
    
    func testOngoingActivityTypes() {
        XCTAssertTrue(UniversalActivityType.building.isOngoing)
        XCTAssertTrue(UniversalActivityType.rendering.isOngoing)
        XCTAssertTrue(UniversalActivityType.processing.isOngoing)
        XCTAssertTrue(UniversalActivityType.mediaPlaying.isOngoing)
        XCTAssertTrue(UniversalActivityType.syncing.isOngoing)
        XCTAssertFalse(UniversalActivityType.appActive.isOngoing)
        XCTAssertFalse(UniversalActivityType.completed.isOngoing)
    }
}
