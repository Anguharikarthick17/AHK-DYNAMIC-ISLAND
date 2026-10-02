import AppKit
import Foundation

/// Delegate protocol for IslandWindow user interaction events.
@MainActor
public protocol IslandWindowDelegate: AnyObject {
    func islandWindowDidRequestCollapse(_ window: IslandWindow)
    func islandWindowDidResignKey(_ window: IslandWindow)
}

/// A dedicated borderless, non-activating floating panel positioned around the macOS notch area.
public final class IslandWindow: NSPanel {
    
    public weak var interactionDelegate: IslandWindowDelegate?
    
    /// Controls whether the window is currently allowed to become key window (e.g., when expanded).
    public var allowsKeyStatus: Bool = false
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindowAttributes()
    }
    
    private func setupWindowAttributes() {
        // Transparency and borderless presentation
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        
        // Window strata: Float at status-bar level alongside the notch
        level = .statusBar
        
        // Space behaviors: visible on all desktop spaces and fullscreen apps
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        // Window interaction properties
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }
    
    // MARK: - Key & Main Window Behavior
    
    public override var canBecomeKey: Bool {
        return allowsKeyStatus
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public override func resignKey() {
        super.resignKey()
        interactionDelegate?.islandWindowDidResignKey(self)
    }
    
    // MARK: - Keyboard Handling
    
    public override func keyDown(with event: NSEvent) {
        // Escape key code is 53
        if event.keyCode == 53 {
            interactionDelegate?.islandWindowDidRequestCollapse(self)
            return
        }
        super.keyDown(with: event)
    }
}
