import AppKit
import Foundation

/// Coordinates the lifecycle, geometry, state, and animation of the Dynamic Island window.
@MainActor
public final class IslandWindowController: NSObject, IslandViewDelegate, IslandWindowDelegate {
    
    public let window: IslandWindow
    public let islandView: IslandView
    public let geometryProvider: NotchGeometryProvider
    public let stateManager: IslandStateManager
    public let animator: IslandAnimator
    public let displayObserver: DisplayObserver
    
    public private(set) var currentGeometry: ScreenGeometryInfo
    
    public var onStateChanged: ((IslandDisplayState) -> Void)?
    public var onVisibilityChanged: ((Bool) -> Void)?
    
    public init(
        geometryProvider: NotchGeometryProvider = NotchGeometryProvider(),
        stateManager: IslandStateManager = IslandStateManager()
    ) {
        self.geometryProvider = geometryProvider
        self.stateManager = stateManager
        self.animator = IslandAnimator()
        self.displayObserver = DisplayObserver()
        
        // Initial screen geometry calculation
        let screen = geometryProvider.targetScreen() ?? NSScreen.main ?? NSScreen.screens[0]
        let initialGeometry = geometryProvider.geometry(for: screen)
        self.currentGeometry = initialGeometry
        
        // Initialize window at collapsed frame
        self.window = IslandWindow(contentRect: initialGeometry.collapsedFrame)
        self.islandView = IslandView(frame: NSRect(origin: .zero, size: initialGeometry.collapsedFrame.size))
        
        super.init()
        
        setupController()
    }
    
    private func setupController() {
        window.contentView = islandView
        islandView.delegate = self
        window.interactionDelegate = self
        
        islandView.updateGeometry(info: currentGeometry)
        islandView.applyContainerStyle(isExpanded: false)
        islandView.setContentAlpha(0.0)
        
        // State forwarding
        stateManager.onStateChanged = { [weak self] state in
            self?.onStateChanged?(state)
        }
        stateManager.onVisibilityChanged = { [weak self] isVisible in
            self?.onVisibilityChanged?(isVisible)
        }
        
        // Display observer setup
        displayObserver.startObserving { [weak self] in
            self?.handleDisplayConfigurationChanged()
        }
    }
    
    // MARK: - Display Configuration Updates
    
    public func handleDisplayConfigurationChanged() {
        guard let screen = geometryProvider.targetScreen() else { return }
        let newGeometry = geometryProvider.geometry(for: screen)
        self.currentGeometry = newGeometry
        
        islandView.updateGeometry(info: newGeometry)
        
        let targetFrame: NSRect
        switch stateManager.currentState {
        case .expanded, .expanding:
            targetFrame = newGeometry.expandedFrame
        case .collapsed, .collapsing:
            targetFrame = newGeometry.collapsedFrame
        }
        
        // Update frame without recreating the window
        animator.setImmediately(window: window, targetFrame: targetFrame) { [weak self] in
            guard let self = self else { return }
            self.islandView.frame = NSRect(origin: .zero, size: targetFrame.size)
        }
    }
    
    // MARK: - Visibility Control
    
    public func show() {
        stateManager.setVisibility(true)
        window.orderFront(nil)
    }
    
    public func hide() {
        stateManager.setVisibility(false)
        window.orderOut(nil)
    }
    
    public func toggleVisibility() {
        if stateManager.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Expand / Collapse Actions
    
    public func expand(animated: Bool = true) {
        guard stateManager.transition(to: .expanding) else { return }
        
        let targetFrame = currentGeometry.expandedFrame
        window.allowsKeyStatus = true
        
        if animated {
            animator.animate(
                window: window,
                targetFrame: targetFrame,
                parameters: .defaultSpring,
                viewAnimations: { [weak self] in
                    guard let self = self else { return }
                    self.islandView.frame = NSRect(origin: .zero, size: targetFrame.size)
                    self.islandView.applyContainerStyle(isExpanded: true)
                    self.islandView.setContentAlpha(1.0)
                },
                completion: { [weak self] completed in
                    guard let self = self, completed else { return }
                    self.stateManager.transition(to: .expanded)
                    self.window.makeKey()
                }
            )
        } else {
            animator.setImmediately(window: window, targetFrame: targetFrame) { [weak self] in
                guard let self = self else { return }
                self.islandView.frame = NSRect(origin: .zero, size: targetFrame.size)
                self.islandView.applyContainerStyle(isExpanded: true)
                self.islandView.setContentAlpha(1.0)
            }
            stateManager.transition(to: .expanded)
            window.makeKey()
        }
    }
    
    public func collapse(animated: Bool = true) {
        guard stateManager.transition(to: .collapsing) else { return }
        
        let targetFrame = currentGeometry.collapsedFrame
        
        // Resign key status immediately so keyboard returns to previous app
        window.allowsKeyStatus = false
        window.resignKey()
        
        if animated {
            animator.animate(
                window: window,
                targetFrame: targetFrame,
                parameters: .quickCollapse,
                viewAnimations: { [weak self] in
                    guard let self = self else { return }
                    self.islandView.frame = NSRect(origin: .zero, size: targetFrame.size)
                    self.islandView.applyContainerStyle(isExpanded: false)
                    self.islandView.setContentAlpha(0.0)
                },
                completion: { [weak self] completed in
                    guard let self = self, completed else { return }
                    self.stateManager.transition(to: .collapsed)
                }
            )
        } else {
            animator.setImmediately(window: window, targetFrame: targetFrame) { [weak self] in
                guard let self = self else { return }
                self.islandView.frame = NSRect(origin: .zero, size: targetFrame.size)
                self.islandView.applyContainerStyle(isExpanded: false)
                self.islandView.setContentAlpha(0.0)
            }
            stateManager.transition(to: .collapsed)
        }
    }
    
    public func toggleExpandCollapse(animated: Bool = true) {
        switch stateManager.toggledTargetState {
        case .expanded:
            expand(animated: animated)
        case .collapsed:
            collapse(animated: animated)
        default:
            break
        }
    }
    
    // MARK: - IslandViewDelegate
    
    public func islandViewDidRequestToggleExpandCollapse(_ view: IslandView) {
        toggleExpandCollapse(animated: true)
    }
    
    public func islandViewDidRequestCollapse(_ view: IslandView) {
        collapse(animated: true)
    }
    
    // MARK: - IslandWindowDelegate
    
    public func islandWindowDidRequestCollapse(_ window: IslandWindow) {
        collapse(animated: true)
    }
    
    public func islandWindowDidResignKey(_ window: IslandWindow) {
        // Optional collapse on focus loss if currently expanded
        if stateManager.currentState == .expanded {
            collapse(animated: true)
        }
    }
}
