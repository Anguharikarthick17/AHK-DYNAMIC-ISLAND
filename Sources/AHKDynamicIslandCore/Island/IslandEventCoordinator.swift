import Foundation

/// Central coordinator for dynamic island events, priorities, queuing, and auto-dismissal.
@MainActor
public final class IslandEventCoordinator {
    
    public private(set) var activeActivity: IslandActivity = .idle
    private var queuedActivities: [IslandActivity] = []
    private var autoDismissTask: Task<Void, Never>?
    
    public var onActivityChanged: ((IslandActivity) -> Void)?
    
    public init() {}
    
    /// Posts a new activity to the coordinator. Evaluates priority and preempts or queues.
    public func postActivity(_ activity: IslandActivity) {
        if activity == .idle {
            clearCurrentActivity()
            return
        }
        
        // If current activity is idle, immediately present
        if activeActivity == .idle {
            presentActivity(activity)
            return
        }
        
        // Transient HUD events (volume, brightness) temporarily preempt persistent activities
        // unless preempted by a critical alert
        if activity.isTransientHUD {
            if activeActivity.priority < .criticalAlert {
                if activeActivity != activity && !activeActivity.isTransientHUD {
                    queuedActivities.append(activeActivity)
                }
                presentActivity(activity)
                return
            } else {
                // Critical alert in progress; drop transient volume HUD
                return
            }
        }
        
        // If the new activity is of higher or equal priority, preempt current
        if activity.priority >= activeActivity.priority {
            // If current was a persistent background activity (e.g. now playing or ongoing app activity), keep in queue
            if case .nowPlaying = activeActivity {
                queuedActivities.append(activeActivity)
            } else if case .appActivity(let currentApp) = activeActivity, currentApp.activityType.isOngoing {
                queuedActivities.append(activeActivity)
            }
            presentActivity(activity)
        } else {
            // Lower priority: queue if relevant (e.g. transfers/downloads/ongoing activities)
            switch activity {
            case .download, .fileTransfer, .notification:
                queuedActivities.append(activity)
            case .appActivity(let app):
                if app.activityType.isOngoing {
                    queuedActivities.append(activity)
                }
            default:
                break // Drop transient volume/brightness if higher priority card is active
            }
        }
    }
    
    /// Clears the currently active activity and restores the next queued activity or idle.
    public func clearCurrentActivity() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        
        if let next = queuedActivities.popLast() {
            presentActivity(next)
        } else {
            activeActivity = .idle
            onActivityChanged?(.idle)
        }
    }
    
    /// Removes activities matching a predicate from queue and clears current if it matches.
    public func removeActivities(matching predicate: (IslandActivity) -> Bool) {
        queuedActivities.removeAll(where: predicate)
        if predicate(activeActivity) {
            clearCurrentActivity()
        }
    }
    
    private func presentActivity(_ activity: IslandActivity) {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        
        self.activeActivity = activity
        onActivityChanged?(activity)
        
        // Configure auto-dismiss timer if applicable
        if let interval = activity.autoDismissInterval {
            autoDismissTask = Task { @MainActor [weak self] in
                let nanoseconds = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                self?.clearCurrentActivity()
            }
        }
    }
    
    /// Manually dismiss current activity (e.g. on user tap).
    public func dismissCurrent() {
        clearCurrentActivity()
    }
}
