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
        
        // Transient HUD events (volume, brightness, charger, completions) temporarily preempt persistent activities
        // unless preempted by a critical alert
        if activity.isTransientHUD {
            if activeActivity.priority < .criticalAlert {
                if activeActivity != activity && !activeActivity.isTransientHUD {
                    let isOwnTimerCompletion: Bool = {
                        if case .timer(_, _, true) = activity, case .timer = activeActivity { return true }
                        return false
                    }()
                    let isOwnDownloadCompletion: Bool = {
                        if case .download(let d) = activity, d.isCompleted, case .download = activeActivity { return true }
                        return false
                    }()
                    let isOwnAppCompletion: Bool = {
                        if case .appActivity(let newApp) = activity,
                           newApp.activityState.isTerminal || newApp.activityType == .completed || newApp.activityType == .error,
                           case .appActivity(let currApp) = activeActivity,
                           currApp.bundleIdentifier == newApp.bundleIdentifier {
                            return true
                        }
                        return false
                    }()
                    
                    if !isOwnTimerCompletion && !isOwnDownloadCompletion && !isOwnAppCompletion {
                        queuedActivities.append(activeActivity)
                    } else {
                        if isOwnTimerCompletion {
                            queuedActivities.removeAll { if case .timer = $0 { return true }; return false }
                        }
                        if isOwnDownloadCompletion {
                            queuedActivities.removeAll { if case .download = $0 { return true }; return false }
                        }
                        if isOwnAppCompletion, case .appActivity(let newApp) = activity {
                            queuedActivities.removeAll { if case .appActivity(let a) = $0, a.bundleIdentifier == newApp.bundleIdentifier { return true }; return false }
                        }
                    }
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
            // Completed timer, download, or app activity finishes the activity; purge prior running instances
            if case .timer(_, _, true) = activity {
                queuedActivities.removeAll { if case .timer = $0 { return true }; return false }
            }
            if case .download(let d) = activity, d.isCompleted {
                queuedActivities.removeAll { if case .download = $0 { return true }; return false }
            }
            if case .appActivity(let newApp) = activity, newApp.activityState.isTerminal || newApp.activityType == .completed || newApp.activityType == .error {
                queuedActivities.removeAll { if case .appActivity(let a) = $0, a.bundleIdentifier == newApp.bundleIdentifier { return true }; return false }
            }
            
            // If current was a persistent background activity (e.g. now playing, app activity, active timer), keep in queue
            if case .nowPlaying = activeActivity {
                queuedActivities.append(activeActivity)
            } else if case .appActivity(let currentApp) = activeActivity {
                let isSameAppFinishing: Bool = {
                    if case .appActivity(let newApp) = activity, newApp.bundleIdentifier == currentApp.bundleIdentifier {
                        return true
                    }
                    return false
                }()
                if !isSameAppFinishing {
                    queuedActivities.append(activeActivity)
                }
            } else if case .timer(_, _, false) = activeActivity {
                if case .timer(_, _, true) = activity {
                    // Completing the timer; do not re-queue the running timer!
                } else {
                    queuedActivities.append(activeActivity)
                }
            } else if case .download(let d) = activeActivity, !d.isCompleted {
                if case .download(let newD) = activity, newD.isCompleted {
                    // Completing the download; do not re-queue the active download!
                } else {
                    queuedActivities.append(activeActivity)
                }
            }
            presentActivity(activity)
        } else {
            // Lower priority: queue if relevant (e.g. transfers/downloads/ongoing activities/active timer)
            switch activity {
            case .download, .fileTransfer, .notification:
                queuedActivities.append(activity)
            case .timer(_, _, false):
                queuedActivities.append(activity)
            case .appActivity(let app):
                if app.isOngoing {
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
