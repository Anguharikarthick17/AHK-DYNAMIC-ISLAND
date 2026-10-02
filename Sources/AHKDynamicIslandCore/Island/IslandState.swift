import Foundation

/// Priority tiers for dynamic island activities.
public enum ActivityPriority: Int, Comparable, Sendable {
    case idle = 0
    case appActive = 5
    case volume = 10
    case brightness = 15
    case appProcessing = 18
    case nowPlaying = 20
    case battery = 25
    case fileTransfer = 30
    case download = 40
    case criticalAlert = 50
    
    // Semantic priority aliases adhering to Section 21
    public static let low = ActivityPriority.appActive
    public static let medium = ActivityPriority.appProcessing
    public static let high = ActivityPriority.volume
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
            return activity.priority
        case .volume:
            return .volume
        case .brightness:
            return .brightness
        case .battery(_, _, _, let isCritical):
            return isCritical ? .criticalAlert : .battery
        case .nowPlaying:
            return .nowPlaying
        case .fileTransfer:
            return .fileTransfer
        case .download:
            return .download
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
        case .nowPlaying:
            return nil // Remains active while playing
        case .download(let state):
            return state.isCompleted ? 2.0 : nil
        case .fileTransfer(let state):
            return state.isCompleted ? 2.0 : nil
        case .notification:
            return 3.5
        case .appActivity(let activity):
            if activity.activityType.isOngoing {
                return nil // Persistent while actively building, rendering, playing, syncing
            } else if activity.activityType == .completed {
                return 2.0
            } else {
                return 3.0 // Generic active presentation (auto-collapses to idle AHK MAC)
            }
        }
    }
    
    /// Whether this is a transient HUD event that temporarily interrupts persistent activities.
    public var isTransientHUD: Bool {
        switch self {
        case .volume, .brightness:
            return true
        default:
            return false
        }
    }
    
    /// Whether this activity contains interactive elements (e.g. media controls).
    public var isInteractive: Bool {
        switch self {
        case .nowPlaying:
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

/// Manages dynamic island state and active activities.
public final class IslandStateManager: @unchecked Sendable {
    
    public private(set) var currentState: IslandDisplayState
    public private(set) var currentActivity: IslandActivity
    public private(set) var isVisible: Bool
    
    public var onStateChanged: ((IslandDisplayState) -> Void)?
    public var onActivityChanged: ((IslandActivity) -> Void)?
    public var onVisibilityChanged: ((Bool) -> Void)?
    
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
