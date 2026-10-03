import Foundation

/// In-memory registry tracking multi-tab Chrome activity state.
/// Adheres strictly to Section 12, 13, and 14 for multi-tab activity arbitration
/// and background activity preservation.
public final class ChromeActivityRegistry: @unchecked Sendable {
    
    public static let shared = ChromeActivityRegistry()
    
    private let lock = NSLock()
    private var tabs: [Int: ChromeTabActivity] = [:]
    public private(set) var activeTabId: Int?
    public private(set) var focusedWindowId: Int?
    
    public init() {}
    
    public func setFocusedWindowId(_ windowId: Int) {
        lock.lock()
        defer { lock.unlock() }
        self.focusedWindowId = windowId
        if let tabInWin = tabs.values.filter({ $0.windowId == windowId }).max(by: { ($0.isActiveTab ? 1 : 0, $0.timestamp) < ($1.isActiveTab ? 1 : 0, $1.timestamp) }) {
            self.activeTabId = tabInWin.tabId
            for (id, existing) in tabs {
                let isCurrent = (id == tabInWin.tabId)
                tabs[id] = ChromeTabActivity(
                    tabId: existing.tabId,
                    windowId: existing.windowId,
                    applicationName: existing.applicationName,
                    siteName: existing.siteName,
                    hostname: existing.hostname,
                    title: existing.title,
                    activityType: existing.activityType,
                    activityState: existing.activityState,
                    confidence: existing.confidence,
                    priority: existing.priority,
                    progress: existing.progress,
                    timeString: existing.timeString,
                    activitySubtitle: existing.activitySubtitle,
                    glyph: existing.glyph,
                    timestamp: existing.timestamp,
                    isActiveTab: isCurrent,
                    metadata: existing.metadata
                )
            }
        }
    }
    
    /// Records or updates activity for a given Chrome tab.
    public func updateTabActivity(_ activity: ChromeTabActivity) {
        lock.lock()
        defer { lock.unlock() }
        tabs[activity.tabId] = activity
        if activity.isActiveTab {
            activeTabId = activity.tabId
            if let winId = activity.windowId {
                focusedWindowId = winId
            }
            for (id, existing) in tabs where id != activity.tabId && existing.isActiveTab {
                tabs[id] = ChromeTabActivity(
                    tabId: existing.tabId,
                    windowId: existing.windowId,
                    applicationName: existing.applicationName,
                    siteName: existing.siteName,
                    hostname: existing.hostname,
                    title: existing.title,
                    activityType: existing.activityType,
                    activityState: existing.activityState,
                    confidence: existing.confidence,
                    priority: existing.priority,
                    progress: existing.progress,
                    timeString: existing.timeString,
                    activitySubtitle: existing.activitySubtitle,
                    glyph: existing.glyph,
                    timestamp: existing.timestamp,
                    isActiveTab: false,
                    metadata: existing.metadata
                )
            }
        }
    }
    
    /// Sets the currently focused Chrome tab and optionally window.
    public func setActiveTabId(_ tabId: Int, windowId: Int? = nil) {
        lock.lock()
        defer { lock.unlock() }
        self.activeTabId = tabId
        if let winId = windowId {
            self.focusedWindowId = winId
        }
        for (id, existing) in tabs {
            let isCurrent = (id == tabId)
            tabs[id] = ChromeTabActivity(
                tabId: existing.tabId,
                windowId: existing.windowId,
                applicationName: existing.applicationName,
                siteName: existing.siteName,
                hostname: existing.hostname,
                title: existing.title,
                activityType: existing.activityType,
                activityState: existing.activityState,
                confidence: existing.confidence,
                priority: existing.priority,
                progress: existing.progress,
                timeString: existing.timeString,
                activitySubtitle: existing.activitySubtitle,
                glyph: existing.glyph,
                timestamp: existing.timestamp,
                isActiveTab: isCurrent,
                metadata: existing.metadata
            )
        }
    }
    
    /// Removes a closed tab from the registry.
    public func removeTab(tabId: Int) {
        lock.lock()
        defer { lock.unlock() }
        tabs.removeValue(forKey: tabId)
        if activeTabId == tabId {
            activeTabId = nil
        }
    }
    
    /// Purges all tabs (e.g., when Chrome closes or disconnects).
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        tabs.removeAll()
        activeTabId = nil
        focusedWindowId = nil
    }
    
    /// Returns all registered tab activities.
    public func allActivities() -> [ChromeTabActivity] {
        lock.lock()
        defer { lock.unlock() }
        return Array(tabs.values)
    }
    
    /// Resolves the primary Chrome activity to present on the Dynamic Island.
    /// Strictly adheres to V0.6.1 Section 3, 4, and 7:
    /// CURRENTLY ACTIVE CHROME TAB OF FOCUSED WINDOW > ALL BACKGROUND CHROME TABS.
    /// Background activities MUST NEVER steal visible priority from the active tab.
    public func resolvePrimaryActivity() -> ChromeTabActivity? {
        lock.lock()
        defer { lock.unlock() }
        
        guard !tabs.isEmpty else { return nil }
        
        // 1. Focused window active tab (Section 7)
        if let focusedWin = focusedWindowId {
            if let activeInFocusedWin = tabs.values.first(where: { $0.windowId == focusedWin && $0.isActiveTab }) {
                return activeInFocusedWin
            }
            if let anyInFocusedWin = tabs.values.filter({ $0.windowId == focusedWin }).max(by: { $0.timestamp < $1.timestamp }) {
                return anyInFocusedWin
            }
        }
        
        // 2. Currently active tab (Section 3 & 4)
        if let currentActiveId = activeTabId, let activeTab = tabs[currentActiveId] {
            return activeTab
        }
        
        // 3. Any active tab
        if let anyActive = tabs.values.first(where: { $0.isActiveTab }) {
            return anyActive
        }
        
        // 4. Fall back to the most recently updated tab
        return tabs.values.max(by: { $0.timestamp < $1.timestamp })
    }
}
