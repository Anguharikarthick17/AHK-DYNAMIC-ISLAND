import XCTest
import AppKit
import QuartzCore
@testable import AHKDynamicIslandCore

@MainActor
final class LiquidGlassMotionAndShineTests: XCTestCase {

    // MARK: - Surface Layer Stack Tests

    func testLiquidIslandSurfaceLayerHierarchy() {
        let surface = LiquidIslandSurface(frame: NSRect(x: 0, y: 0, width: 200, height: 36))
        surface.layout()

        XCTAssertNotNil(surface.contentView)
        XCTAssertNotNil(surface.highlightSweep)
        XCTAssertNotNil(surface.borderRim)
        XCTAssertEqual(surface.cornerRadius, 13.0, accuracy: 0.1)

        // Shadow configuration
        XCTAssertEqual(surface.layer?.shadowRadius, 12.0)
        XCTAssertEqual(surface.layer?.shadowOffset, CGSize(width: 0, height: -3.5))
    }

    func testSurfaceCornerRadiusPropagation() {
        let surface = LiquidIslandSurface(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        surface.cornerRadius = 20.0
        surface.layout()

        XCTAssertEqual(surface.cornerRadius, 20.0)
        XCTAssertEqual(surface.highlightSweep.cornerRadius, 20.0)
        XCTAssertEqual(surface.borderRim.cornerRadius, 20.0)
    }

    // MARK: - Specular Light Sweep Tests

    func testHighlightRestingStateAndSweep() {
        let highlight = LiquidIslandHighlight()
        highlight.frame = CGRect(x: 0, y: 0, width: 200, height: 36)
        highlight.layoutSublayers()

        // Trigger sweep
        highlight.sweep(intensity: 1.0, duration: 1.2)
        
        // Stop sweep returns to resting offscreen state
        highlight.stopSweep()
        XCTAssertTrue(highlight.masksToBounds)
    }

    func testHighlightAppearanceModes() {
        let highlight = LiquidIslandHighlight()
        
        // Dark mode
        highlight.setAppearance(isDark: true)
        
        // Light mode
        highlight.setAppearance(isDark: false)
    }

    // MARK: - Border Highlight Tests

    func testBorderRimSweepAndRest() {
        let border = LiquidIslandBorder()
        border.frame = CGRect(x: 0, y: 0, width: 210, height: 38)
        border.cornerRadius = 19.0
        border.layoutSublayers()

        border.sweepBorder(duration: 1.0)
        border.stopBorderSweep()
        
        XCTAssertFalse(border.masksToBounds)
    }

    func testBorderRimAppearanceModes() {
        let border = LiquidIslandBorder()
        border.setAppearance(isDark: true)
        border.setAppearance(isDark: false)
    }

    // MARK: - Animator Orchestration Tests

    func testAnimatorActivityAndIdleTransitions() {
        let surface = LiquidIslandSurface(frame: NSRect(x: 0, y: 0, width: 180, height: 26))
        let animator = LiquidIslandAnimator(surface: surface)

        // Idle state: starts scheduled cadence
        animator.updateActivityState(.idle)

        // Real activity state: fires activity shine
        let volAct = IslandActivity.volume(level: 0.75, isMuted: false)
        animator.updateActivityState(volAct)

        // Hidden state pauses all animation
        animator.setVisibility(isVisible: false)
        animator.setVisibility(isVisible: true)
        
        animator.pauseIdleAnimation()
    }

    // MARK: - Container Integration Tests

    func testLiquidGlassContainerViewSurfaceDelegation() {
        let container = LiquidGlassContainerView(frame: NSRect(x: 0, y: 0, width: 160, height: 28))
        XCTAssertNotNil(container.surface)
        XCTAssertEqual(container.contentView, container.surface.contentView)
        
        container.cornerRadius = 14.0
        XCTAssertEqual(container.surface.cornerRadius, 14.0)

        container.isInteractive = true
        XCTAssertTrue(container.surface.isInteractive)
        
        container.performActivityShine()
        container.performIdleShine()
        container.stopAllShine()
    }

    // MARK: - AHK Signature & Idle Presentation Tests

    func testIslandViewAHKSignaturePresence() {
        let islandView = IslandView(frame: NSRect(x: 0, y: 0, width: 180, height: 26))
        
        XCTAssertEqual(islandView.signatureLabel.stringValue, "✦")
        XCTAssertFalse(islandView.signatureLabel.isEditable)
        XCTAssertNotNil(islandView.liquidAnimator)
        XCTAssertEqual(islandView.idleLabel.stringValue, DeviceIdentityManager.shared.computerName)
    }
}
