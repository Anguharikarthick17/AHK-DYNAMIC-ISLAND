import AppKit
import Foundation

/// Coordinates the lifecycle, geometry, activity state, and dynamic animations of the Dynamic Island window.
@MainActor
public final class IslandWindowController: NSObject, IslandViewDelegate, IslandWindowDelegate {
    
    public let window: IslandWindow
    public let islandView: IslandView
    public let geometryProvider: NotchGeometryProvider
    public let stateManager: IslandStateManager
    public let animator: IslandAnimator
    public let displayObserver: DisplayObserver
    public let layoutEngine: IslandLayoutEngine
    public let cursorAvoidanceController: CursorAvoidanceController
    
    public private(set) var currentGeometry: ScreenGeometryInfo
    
    public var onStateChanged: ((IslandDisplayState) -> Void)?
    public var onActivityChanged: ((IslandActivity) -> Void)?
    public var onVisibilityChanged: ((Bool) -> Void)?
    public var onPresentationStateChanged: ((IslandPresentationState) -> Void)?
    
    public init(
        geometryProvider: NotchGeometryProvider = NotchGeometryProvider(),
        stateManager: IslandStateManager = IslandStateManager(),
        layoutEngine: IslandLayoutEngine = IslandLayoutEngine.shared
    ) {
        self.geometryProvider = geometryProvider
        self.stateManager = stateManager
        self.layoutEngine = layoutEngine
        self.animator = IslandAnimator()
        self.displayObserver = DisplayObserver()
        
        let screen = geometryProvider.targetScreen() ?? NSScreen.main ?? NSScreen.screens[0]
        let initialGeometry = geometryProvider.geometry(for: screen)
        self.currentGeometry = initialGeometry
        
        // Initial layout spec for idle capsule (150x26)
        let initialSpec = layoutEngine.layoutSpec(
            for: .idle,
            isExpanded: false,
            screenGeometry: initialGeometry
        )
        
        let win = IslandWindow(contentRect: initialSpec.frame)
        let view = IslandView(frame: NSRect(origin: .zero, size: initialSpec.frame.size))
        self.window = win
        self.islandView = view
        self.cursorAvoidanceController = CursorAvoidanceController(
            window: win,
            islandView: view,
            stateManager: stateManager
        )
        
        super.init()
        
        setupController()
    }
    
    private func setupController() {
        window.contentView = islandView
        islandView.delegate = self
        window.interactionDelegate = self
        
        let initialSpec = layoutEngine.layoutSpec(
            for: .idle,
            isExpanded: false,
            screenGeometry: currentGeometry
        )
        islandView.applyLayout(
            size: initialSpec.size,
            cornerRadius: initialSpec.cornerRadius
        )
        
        // Forward state notifications
        stateManager.onStateChanged = { [weak self] state in
            self?.onStateChanged?(state)
        }
        stateManager.onPresentationStateChanged = { [weak self] pState in
            self?.onPresentationStateChanged?(pState)
        }
        stateManager.onActivityChanged = { [weak self] activity in
            self?.onActivityChanged?(activity)
        }
        stateManager.onVisibilityChanged = { [weak self] isVisible in
            self?.onVisibilityChanged?(isVisible)
        }
        
        displayObserver.startObserving { [weak self] in
            self?.handleDisplayConfigurationChanged()
        }
    }
    
    // MARK: - Display Configuration Updates
    
    public func handleDisplayConfigurationChanged() {
        guard let screen = geometryProvider.targetScreen() else { return }
        let newGeometry = geometryProvider.geometry(for: screen)
        self.currentGeometry = newGeometry
        
        let isExpanded = stateManager.currentState.isExpandedOrExpanding
        let targetSpec = layoutEngine.layoutSpec(
            for: stateManager.currentActivity,
            isExpanded: isExpanded,
            screenGeometry: newGeometry
        )
        
        animator.setImmediately(window: window, targetFrame: targetSpec.frame) { [weak self] in
            guard let self = self else { return }
            self.islandView.frame = NSRect(origin: .zero, size: targetSpec.frame.size)
            self.islandView.applyLayout(size: targetSpec.size, cornerRadius: targetSpec.cornerRadius)
        }
    }
    
    // MARK: - Visibility Control
    
    public func show() {
        stateManager.setVisibility(true)
        islandView.liquidAnimator.setVisibility(isVisible: true)
        window.orderFront(nil)
    }
    
    public func hide() {
        stateManager.setVisibility(false)
        islandView.liquidAnimator.setVisibility(isVisible: false)
        window.orderOut(nil)
    }
    
    public func toggleVisibility() {
        if stateManager.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Activity Presentation
    
    public func presentActivity(_ activity: IslandActivity, isExpanded: Bool = false, animated: Bool = true) {
        stateManager.setActivity(activity)
        let spec = layoutEngine.layoutSpec(for: activity, isExpanded: isExpanded, screenGeometry: currentGeometry)
        
        window.allowsKeyStatus = isExpanded
        islandView.present(activity: activity, isExpanded: isExpanded)
        
        if animated {
            let transitionState: IslandDisplayState = isExpanded ? .expanding : .collapsing
            stateManager.transition(to: transitionState)
            
            animator.animate(
                window: window,
                targetFrame: spec.frame,
                parameters: isExpanded ? .defaultSpring : .quickCollapse,
                viewAnimations: { [weak self] in
                    guard let self = self else { return }
                    self.islandView.frame = NSRect(origin: .zero, size: spec.frame.size)
                    self.islandView.applyLayout(size: spec.size, cornerRadius: spec.cornerRadius)
                },
                completion: { [weak self] completed in
                    guard let self = self, completed else { return }
                    self.stateManager.transition(to: isExpanded ? .expanded : .collapsed)
                    if isExpanded {
                        self.window.makeKey()
                    }
                }
            )
        } else {
            animator.setImmediately(window: window, targetFrame: spec.frame) { [weak self] in
                guard let self = self else { return }
                self.islandView.frame = NSRect(origin: .zero, size: spec.frame.size)
                self.islandView.applyLayout(size: spec.size, cornerRadius: spec.cornerRadius)
            }
            stateManager.transition(to: isExpanded ? .expanded : .collapsed)
            if isExpanded {
                window.makeKey()
            }
        }
    }
    
    // MARK: - Expand / Collapse Actions
    
    public func expand(animated: Bool = true) {
        presentActivity(stateManager.currentActivity, isExpanded: true, animated: animated)
    }
    
    public func collapse(animated: Bool = true) {
        presentActivity(stateManager.currentActivity, isExpanded: false, animated: animated)
    }
    
    public func toggleExpandCollapse(animated: Bool = true) {
        let targetExpanded = !stateManager.currentState.isExpandedOrExpanding
        presentActivity(stateManager.currentActivity, isExpanded: targetExpanded, animated: animated)
    }
    
    // MARK: - IslandViewDelegate
    
    public func islandViewDidRequestToggleExpandCollapse(_ view: IslandView) {
        toggleExpandCollapse(animated: true)
    }
    
    public func islandViewDidRequestDismissActivity(_ view: IslandView) {
        presentActivity(.idle, isExpanded: false, animated: true)
    }
    
    public func islandViewDidDetectCursorApproach(_ view: IslandView) {
        cursorAvoidanceController.handleCursorEntered()
    }
    
    public func islandViewDidDetectCursorExit(_ view: IslandView) {
        cursorAvoidanceController.handleMouseMoved()
    }
    
    // MARK: - IslandWindowDelegate
    
    public func islandWindowDidRequestCollapse(_ window: IslandWindow) {
        collapse(animated: true)
    }
    
    public func islandWindowDidResignKey(_ window: IslandWindow) {
        // Keep expanded until user explicitly clicks the island or presses Escape
    }
}
