import Foundation

/// Priority tiers for dynamic island activities.
public enum ActivityPriority: Int, Comparable, Sendable {
    case idle = 0
    case appActive = 5
    case volume = 10
    case brightness = 15
    case appProcessing = 18
    case nowPlaying = 20
    case timerRunning = 21
    case battery = 25
    case clipboard = 28
    case fileTransfer = 30
    case appTask = 32
    case audioDevice = 35
    case network = 36
    case charger = 38
    case download = 40
    case activityCompletion = 45
    case criticalAlert = 50
    
    // Semantic priority aliases adhering to Section 11 & Section 21
    public static let low = ActivityPriority.appActive
    public static let medium = ActivityPriority.nowPlaying
    public static let high = ActivityPriority.audioDevice
    public static let critical = ActivityPriority.criticalAlert
    
    public static func < (lhs: ActivityPriority, rhs: ActivityPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// The active content/activity payload currently presented by the dynamic island.
public enum IslandActivity: Equatable, Sendable {
    case idle
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case battery(level: Float, isCharging: Bool, isLow: Bool, isCritical: Bool)
    case charger(isConnected: Bool, percent: Int)
    case audioDevice(name: String, isConnected: Bool, icon: String)
    case network(statusText: String, icon: String, isWarning: Bool)
    case timer(remainingSeconds: TimeInterval, totalSeconds: TimeInterval, isCompleted: Bool)
    case clipboard(statusText: String)
    case nowPlaying(state: NowPlayingState)
    case download(state: DownloadState)
    case fileTransfer(state: FileTransferState)
    case notification(title: String, subtitle: String?, iconName: String?)
    case appActivity(activity: UniversalAppActivity)
    
    /// Priority of this activity.
    public var priority: ActivityPriority {
        switch self {
        case .idle:
            return .idle
        case .appActivity(let activity):
            if activity.activityState.isTerminal || activity.activityType == .completed || activity.activityType == .error {
                return .activityCompletion
            }
            if activity.isOngoing {
                return activity.priority > .appActive ? activity.priority : .appTask
            }
            return activity.priority
        case .volume:
            return .volume
        case .brightness:
            return .brightness
        case .battery(_, _, _, let isCritical):
            return isCritical ? .criticalAlert : .battery
        case .charger:
            return .charger
        case .audioDevice:
            return .audioDevice
        case .network:
            return .network
        case .timer(_, _, let isCompleted):
            return isCompleted ? .criticalAlert : .timerRunning
        case .clipboard:
            return .clipboard
        case .nowPlaying:
            return .nowPlaying
        case .fileTransfer:
            return .fileTransfer
        case .download(let state):
            return state.isCompleted ? .download : .fileTransfer
        case .notification:
            return .fileTransfer
        }
    }
    
    /// Default display duration before auto-collapsing to idle or previous persistent state.
    public var autoDismissInterval: TimeInterval? {
        switch self {
        case .idle:
            return nil
        case .volume, .brightness:
            return 1.8
        case .battery(_, _, _, let isCritical):
            return isCritical ? nil : 3.0
        case .charger:
            return 2.5
        case .audioDevice:
            return 2.2
        case .network:
            return 2.5
        case .clipboard:
            return 1.8
        case .timer(_, _, let isCompleted):
            return isCompleted ? 3.0 : nil // Active countdown remains persistent
        case .nowPlaying:
            return nil // Remains active while playing
        case .download(let state):
            return state.isCompleted ? 2.0 : nil
        case .fileTransfer(let state):
            return state.isCompleted ? 2.0 : nil
        case .notification:
            return 3.5
        case .appActivity(let activity):
            if activity.activityState.isTerminal || activity.activityType == .completed || activity.activityType == .error {
                return 2.5 // Short transient display for completion/failure
            } else if activity.activityState.isOngoing || activity.activityType.isOngoing {
                return nil // Persistent while actively building, rendering, playing, syncing
            } else {
                return 3.0 // Generic active presentation (auto-collapses to idle device identity)
            }
        }
    }
    
    /// Whether this is a transient HUD event that temporarily interrupts persistent activities.
    public var isTransientHUD: Bool {
        switch self {
        case .volume, .brightness, .charger, .audioDevice, .network, .clipboard:
            return true
        case .download(let state):
            return state.isCompleted
        case .timer(_, _, let isCompleted):
            return isCompleted
        case .appActivity(let activity):
            return activity.activityState.isTerminal || activity.activityType == .completed || activity.activityType == .error
        default:
            return false
        }
    }
    
    /// Whether this activity contains interactive elements (e.g. media controls, timer tap).
    public var isInteractive: Bool {
        switch self {
        case .nowPlaying, .timer:
            return true
        case .appActivity(let activity):
            return activity.activityType == .mediaPlaying
        default:
            return false
        }
    }
}

/// Represents the presentation state of the dynamic island.
public enum IslandDisplayState: String, Equatable, Sendable {
    case collapsed
    case expanding
    case expanded
    case collapsing
    
    public var isExpandedOrExpanding: Bool {
        return self == .expanded || self == .expanding
    }
    
    public var isCollapsedOrCollapsing: Bool {
        return self == .collapsed || self == .collapsing
    }
    
    public var canExpand: Bool {
        return self == .collapsed || self == .collapsing
    }
    
    public var canCollapse: Bool {
        return self == .expanded || self == .expanding
    }
}

/// Dedicated presentation state for visual Dynamic Island behavior (independent of activity lifecycle).
public enum IslandPresentationState: String, Equatable, Sendable {
    case visible
    case cursorAvoidanceHidden
    case activityHidden
    case transitioning
}

/// Manages dynamic island state and active activities.
public final class IslandStateManager: @unchecked Sendable {
    
    public private(set) var currentState: IslandDisplayState
    public private(set) var currentActivity: IslandActivity
    public private(set) var presentationState: IslandPresentationState = .visible
    public private(set) var isVisible: Bool
    
    public var onStateChanged: ((IslandDisplayState) -> Void)?
    public var onPresentationStateChanged: ((IslandPresentationState) -> Void)?
    public var onActivityChanged: ((IslandActivity) -> Void)?
    public var onVisibilityChanged: ((Bool) -> Void)?
    
    public func setPresentationState(_ state: IslandPresentationState) {
        guard state != presentationState else { return }
        presentationState = state
        onPresentationStateChanged?(state)
    }
    
    public init(
        initialState: IslandDisplayState = .collapsed,
        initialActivity: IslandActivity = .idle,
        isVisible: Bool = true
    ) {
        self.currentState = initialState
        self.currentActivity = initialActivity
        self.isVisible = isVisible
    }
    
    /// Updates the active activity.
    public func setActivity(_ activity: IslandActivity) {
        guard activity != currentActivity else { return }
        self.currentActivity = activity
        onActivityChanged?(activity)
    }
    
    /// Transitions display state if valid.
    @discardableResult
    public func transition(to newState: IslandDisplayState) -> Bool {
        guard newState != currentState else { return true }
        
        switch (currentState, newState) {
        case (.collapsed, .expanding),
             (.expanding, .expanded),
             (.expanding, .collapsing),
             (.expanded, .collapsing),
             (.collapsing, .collapsed),
             (.collapsing, .expanding),
             (.collapsed, .expanded),
             (.expanded, .collapsed):
            currentState = newState
            onStateChanged?(newState)
            return true
            
        default:
            return false
        }
    }
    
    public var toggledTargetState: IslandDisplayState {
        switch currentState {
        case .collapsed, .collapsing:
            return .expanded
        case .expanded, .expanding:
            return .collapsed
        }
    }
    
    public func setVisibility(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        onVisibilityChanged?(visible)
    }
    
    public func toggleVisibility() {
        setVisibility(!isVisible)
    }
}
