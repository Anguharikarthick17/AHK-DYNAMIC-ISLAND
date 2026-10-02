import Foundation

/// Represents the display state of the dynamic island.
public enum IslandDisplayState: String, Equatable, Sendable {
    case collapsed
    case expanding
    case expanded
    case collapsing
    
    /// Whether the island is fully expanded or currently expanding.
    public var isExpandedOrExpanding: Bool {
        return self == .expanded || self == .expanding
    }
    
    /// Whether the island is fully collapsed or currently collapsing.
    public var isCollapsedOrCollapsing: Bool {
        return self == .collapsed || self == .collapsing
    }
    
    /// Whether an expansion can be initiated.
    public var canExpand: Bool {
        return self == .collapsed || self == .collapsing
    }
    
    /// Whether a collapse can be initiated.
    public var canCollapse: Bool {
        return self == .expanded || self == .expanding
    }
}

/// Manages and validates island state transitions.
public final class IslandStateManager: @unchecked Sendable {
    
    public private(set) var currentState: IslandDisplayState
    public private(set) var isVisible: Bool
    
    public var onStateChanged: ((IslandDisplayState) -> Void)?
    public var onVisibilityChanged: ((Bool) -> Void)?
    
    public init(initialState: IslandDisplayState = .collapsed, isVisible: Bool = true) {
        self.currentState = initialState
        self.isVisible = isVisible
    }
    
    /// Transitions to a target state if valid.
    @discardableResult
    public func transition(to newState: IslandDisplayState) -> Bool {
        guard newState != currentState else { return true }
        
        switch (currentState, newState) {
        case (.collapsed, .expanding),
             (.expanding, .expanded),
             (.expanding, .collapsing), // Interruption
             (.expanded, .collapsing),
             (.collapsing, .collapsed),
             (.collapsing, .expanding): // Interruption
            currentState = newState
            onStateChanged?(newState)
            return true
            
        case (.collapsed, .expanded):
            // Direct jump (e.g. non-animated)
            currentState = newState
            onStateChanged?(newState)
            return true
            
        case (.expanded, .collapsed):
            // Direct jump (e.g. non-animated)
            currentState = newState
            onStateChanged?(newState)
            return true
            
        default:
            return false
        }
    }
    
    /// Returns the target state when toggling expand/collapse.
    public var toggledTargetState: IslandDisplayState {
        switch currentState {
        case .collapsed, .collapsing:
            return .expanded
        case .expanded, .expanding:
            return .collapsed
        }
    }
    
    /// Sets visibility of the island window.
    public func setVisibility(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        onVisibilityChanged?(visible)
    }
    
    /// Toggles visibility.
    public func toggleVisibility() {
        setVisibility(!isVisible)
    }
}
