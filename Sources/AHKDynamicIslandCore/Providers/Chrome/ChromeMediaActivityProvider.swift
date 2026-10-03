import Foundation

/// Universal activity provider translating Chrome tab, website, ChatGPT processing, and media events into UniversalAppActivity.
/// Adheres strictly to Section 2, 3, 4, 5, 11, 12, 13, 14, 15, and 16.
public final class ChromeMediaActivityProvider: UniversalActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.universal"
    public let category: ActivityProviderCategory = .media
    public let isAvailable: Bool = true
    
    // Privacy and API transparency documentation
    public let dataSourceDescription: String = "Local Chrome Native Messaging Host communicating with AHK Universal Activity Chrome Extension."
    public let apiUsedDescription: String = "Chrome Native Messaging (chrome.runtime.connectNative) & DistributedNotificationCenter."
    public let permissionsRequiredDescription: String = "nativeMessaging, tabs. ZERO cookies, zero browsing history, zero prompt/response scraping."
    public let confidence: ActivityConfidence = .high
    public let limitationsDescription: String = "Transparently reports observed tab/media/processing UI states. Falls back to generic Chrome activity with LOW confidence for unspecialized websites."
    
    public var onActivityPublished: (@Sendable (UniversalAppActivity) -> Void)?
    
    private let bridge: ChromeNativeMessagingBridge
    private let lock = NSLock()
    private var currentPrimaryActivity: UniversalAppActivity?
    
    public let activityRegistry = ChromeActivityRegistry.shared
    
    // Sub-providers for specialized site intelligence (Section 5)
    public let chatgptProvider = ChatGPTActivityProvider()
    public let docsProvider = GoogleDocsActivityProvider()
    public let githubProvider = GitHubActivityProvider()
    public let gmailProvider = GmailActivityProvider()
    public let figmaProvider = FigmaActivityProvider()
    public let spotifyProvider = SpotifyWebActivityProvider()
    public let genericProvider = ChromeGenericActivityProvider()
    
    public init(bridge: ChromeNativeMessagingBridge = ChromeNativeMessagingBridge.shared) {
        self.bridge = bridge
        startObserving()
    }
    
    public func startObserving() {
        bridge.startObserving()
        bridge.onMessageReceived = { [weak self] message in
            self?.handleChromeMediaMessage(message)
        }
    }
    
    public func stopObserving() {
        bridge.stopObserving()
        lock.lock()
        currentPrimaryActivity = nil
        activityRegistry.clearAll()
        lock.unlock()
    }
    
    public func canHandle(application: DiscoveredApplication) -> Bool {
        let bundle = application.bundleIdentifier.lowercased()
        let name = application.applicationName.lowercased()
        return bundle.contains("chrome") || name.contains("chrome")
    }
    
    public func resolveActivity(for application: DiscoveredApplication) -> UniversalAppActivity? {
        lock.lock()
        defer { lock.unlock() }
        return currentPrimaryActivity
    }
    
    // MARK: - Message Handling & Multi-Tab Routing
    
    public func handleChromeMediaMessage(_ message: ChromeMediaMessage) {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        
        // Handle Spotify Web through specialized provider even if event is .play or .pause
        if spotifyProvider.canHandle(message: message) {
            if let act = spotifyProvider.produceActivity(for: message) {
                if let tabId = message.tabId {
                    let tabAct = ChromeTabActivity(
                        tabId: tabId,
                        windowId: message.windowId,
                        siteName: "Spotify",
                        hostname: message.hostname,
                        title: act.activityTitle,
                        activityType: act.activityType == .mediaPaused ? .mediaPaused : .mediaPlaying,
                        activityState: act.activityState == .paused ? .paused : .playing,
                        confidence: act.confidence,
                        priority: act.priority,
                        progress: act.progress,
                        timeString: message.formattedTimeString,
                        activitySubtitle: act.activitySubtitle,
                        glyph: act.glyph,
                        timestamp: message.timestamp ?? Date().timeIntervalSince1970,
                        isActiveTab: message.isActiveTab ?? true,
                        metadata: act.metadata
                    )
                    activityRegistry.updateTabActivity(tabAct)
                    if message.event == .tabActivated {
                        activityRegistry.setActiveTabId(tabId)
                    }
                }
                if let primary = activityRegistry.resolvePrimaryActivity() {
                    publishActivity(convertTabToUniversalActivity(primary))
                } else {
                    publishActivity(act)
                }
                return
            }
        }
        
        switch message.event {
        case .disconnect:
            lock.lock()
            currentPrimaryActivity = nil
            activityRegistry.clearAll()
            lock.unlock()
            UniversalActivityRegistry.shared.removeActivity(bundleIdentifier: bundleID)
            
        case .tabRemoved:
            if let tabId = message.tabId {
                activityRegistry.removeTab(tabId: tabId)
                if let nextPrimary = activityRegistry.resolvePrimaryActivity() {
                    let activity = convertTabToUniversalActivity(nextPrimary)
                    publishActivity(activity)
                } else {
                    lock.lock()
                    currentPrimaryActivity = nil
                    lock.unlock()
                    UniversalActivityRegistry.shared.removeActivity(bundleIdentifier: bundleID)
                }
            }
            
        case .ended:
            let title = message.title ?? "YouTube"
            let completed = UniversalAppActivity(
                applicationName: appName,
                bundleIdentifier: bundleID,
                activityType: .completed,
                activityTitle: title,
                activitySubtitle: "Playback Complete",
                activityState: .completed,
                progress: 1.0,
                isIndeterminate: false,
                priority: .activityCompletion,
                confidence: .high,
                source: providerIdentifier,
                glyph: "✓",
                icon: "✓"
            )
            
            if let tabId = message.tabId {
                let tabAct = ChromeTabActivity(
                    tabId: tabId,
                    windowId: message.windowId,
                    siteName: "YouTube",
                    hostname: message.hostname,
                    title: title,
                    activityType: .completed,
                    activityState: .completed,
                    confidence: .high,
                    priority: .activityCompletion,
                    progress: 1.0,
                    timeString: nil,
                    activitySubtitle: "Playback Complete",
                    glyph: "✓",
                    timestamp: message.timestamp ?? Date().timeIntervalSince1970,
                    isActiveTab: message.isActiveTab ?? true,
                    metadata: ["provider": "youtube", "event": "ended"]
                )
                activityRegistry.updateTabActivity(tabAct)
                if message.event == .tabActivated || message.isActiveTab == true {
                    activityRegistry.setActiveTabId(tabId, windowId: message.windowId)
                }
            }
            
            if let primary = activityRegistry.resolvePrimaryActivity() {
                publishActivity(convertTabToUniversalActivity(primary))
            } else {
                publishActivity(completed)
            }
            
        case .play, .timeupdate:
            let title = message.title ?? "YouTube Media"
            let providerName = formattedProviderName(message.provider)
            let artistStr = (message.artist != nil && !message.artist!.isEmpty) ? " • \(message.artist!)" : ""
            let subtitle = "\(providerName)\(artistStr)"
            
            var meta: [String: String] = [
                "provider": message.provider,
                "event": message.event.rawValue
            ]
            if let timeStr = message.formattedTimeString {
                meta["timeString"] = timeStr
            }
            if let art = message.artworkUrl {
                meta["artworkUrl"] = art
            }
            
            let activity = UniversalAppActivity(
                applicationName: appName,
                bundleIdentifier: bundleID,
                activityType: .mediaPlaying,
                activityTitle: title,
                activitySubtitle: subtitle,
                activityState: .playing,
                progress: message.progress,
                isIndeterminate: message.progress == nil,
                priority: .nowPlaying,
                confidence: .high,
                source: providerIdentifier,
                glyph: "▶",
                icon: "▶",
                metadata: meta
            )
            
            if let tabId = message.tabId {
                let tabAct = ChromeTabActivity(
                    tabId: tabId,
                    windowId: message.windowId,
                    siteName: providerName,
                    hostname: message.hostname,
                    title: title,
                    activityType: .mediaPlaying,
                    activityState: .playing,
                    confidence: .high,
                    priority: .nowPlaying,
                    progress: message.progress,
                    timeString: message.formattedTimeString,
                    activitySubtitle: subtitle,
                    glyph: "▶",
                    timestamp: message.timestamp ?? Date().timeIntervalSince1970,
                    isActiveTab: message.isActiveTab ?? true,
                    metadata: meta
                )
                activityRegistry.updateTabActivity(tabAct)
                if message.event == .tabActivated || message.isActiveTab == true {
                    activityRegistry.setActiveTabId(tabId, windowId: message.windowId)
                }
            }
            
            if let primary = activityRegistry.resolvePrimaryActivity() {
                publishActivity(convertTabToUniversalActivity(primary))
            } else {
                publishActivity(activity)
            }
            
        case .pause:
            let title = message.title ?? "YouTube Media"
            let providerName = formattedProviderName(message.provider)
            let artistStr = (message.artist != nil && !message.artist!.isEmpty) ? " • \(message.artist!)" : ""
            let subtitle = "\(providerName)\(artistStr)"
            
            var meta: [String: String] = [
                "provider": message.provider,
                "event": "pause"
            ]
            if let timeStr = message.formattedTimeString {
                meta["timeString"] = timeStr
            }
            
            let activity = UniversalAppActivity(
                applicationName: appName,
                bundleIdentifier: bundleID,
                activityType: .mediaPaused,
                activityTitle: title,
                activitySubtitle: subtitle,
                activityState: .paused,
                progress: message.progress,
                isIndeterminate: false,
                priority: .nowPlaying,
                confidence: .high,
                source: providerIdentifier,
                glyph: "⏸",
                icon: "⏸",
                metadata: meta
            )
            
            if let tabId = message.tabId {
                let tabAct = ChromeTabActivity(
                    tabId: tabId,
                    windowId: message.windowId,
                    siteName: providerName,
                    hostname: message.hostname,
                    title: title,
                    activityType: .mediaPaused,
                    activityState: .paused,
                    confidence: .high,
                    priority: .nowPlaying,
                    progress: message.progress,
                    timeString: message.formattedTimeString,
                    activitySubtitle: subtitle,
                    glyph: "⏸",
                    timestamp: message.timestamp ?? Date().timeIntervalSince1970,
                    isActiveTab: message.isActiveTab ?? true,
                    metadata: meta
                )
                activityRegistry.updateTabActivity(tabAct)
                if message.event == .tabActivated || message.isActiveTab == true {
                    activityRegistry.setActiveTabId(tabId, windowId: message.windowId)
                }
            }
            
            if let primary = activityRegistry.resolvePrimaryActivity() {
                publishActivity(convertTabToUniversalActivity(primary))
            } else {
                publishActivity(activity)
            }
            
        case .activityUpdate, .tabActivated, .stateChange, .other:
            // Route through specialized sub-providers
            let chosenActivity: UniversalAppActivity
            if chatgptProvider.canHandle(message: message) {
                chosenActivity = chatgptProvider.produceActivity(for: message) ?? genericProvider.produceActivity(for: message)!
            } else if docsProvider.canHandle(message: message) {
                chosenActivity = docsProvider.produceActivity(for: message) ?? genericProvider.produceActivity(for: message)!
            } else if spotifyProvider.canHandle(message: message) {
                chosenActivity = spotifyProvider.produceActivity(for: message) ?? genericProvider.produceActivity(for: message)!
            } else if githubProvider.canHandle(message: message) {
                chosenActivity = githubProvider.produceActivity(for: message) ?? genericProvider.produceActivity(for: message)!
            } else if gmailProvider.canHandle(message: message) {
                chosenActivity = gmailProvider.produceActivity(for: message) ?? genericProvider.produceActivity(for: message)!
            } else if figmaProvider.canHandle(message: message) {
                chosenActivity = figmaProvider.produceActivity(for: message) ?? genericProvider.produceActivity(for: message)!
            } else {
                chosenActivity = genericProvider.produceActivity(for: message)!
            }
            
            if let tabId = message.tabId {
                let existingTab = activityRegistry.allActivities().first(where: { $0.tabId == tabId })
                
                var actType = ChromeActivityType.browserActive
                if chosenActivity.activityState == .completed {
                    actType = .completed
                } else if chosenActivity.activitySubtitle?.contains("Processing") == true {
                    actType = .processing
                } else if chosenActivity.activitySubtitle?.contains("Editing") == true {
                    actType = .editing
                } else if chosenActivity.activitySubtitle?.contains("Loading") == true {
                    actType = .pageLoading
                } else if message.event == .tabActivated, let existing = existingTab, (existing.activityType == .mediaPlaying || existing.activityType == .mediaPaused), message.activity == nil {
                    actType = existing.activityType
                }
                
                var actState = ChromeActivityState.active
                if actType == .mediaPlaying {
                    actState = .playing
                } else if actType == .mediaPaused {
                    actState = .paused
                } else if chosenActivity.activityState == .completed {
                    actState = .completed
                } else if chosenActivity.activitySubtitle?.contains("Processing") == true {
                    actState = .processing
                } else if chosenActivity.activitySubtitle?.contains("Editing") == true {
                    actState = .editing
                } else if chosenActivity.activitySubtitle?.contains("Loading") == true {
                    actState = .loading
                }
                
                let isMedia = (actType == .mediaPlaying || actType == .mediaPaused)
                let glyph = isMedia ? (existingTab?.glyph ?? "▶") : chosenActivity.glyph
                let subTitle = isMedia ? existingTab?.activitySubtitle : chosenActivity.activitySubtitle
                let siteName = isMedia ? (existingTab?.siteName ?? "YouTube") : (message.site ?? (chosenActivity.metadata["site"] ?? "Web"))
                let tabTitle = isMedia ? (existingTab?.title ?? chosenActivity.activityTitle) : chosenActivity.activityTitle
                let priority: ActivityPriority = isMedia ? .nowPlaying : chosenActivity.priority
                let confidence: ActivityConfidence = isMedia ? .high : chosenActivity.confidence
                let progress = isMedia ? (existingTab?.progress ?? chosenActivity.progress) : chosenActivity.progress
                let timeString = isMedia ? existingTab?.timeString : nil
                
                let tabAct = ChromeTabActivity(
                    tabId: tabId,
                    windowId: message.windowId,
                    siteName: siteName,
                    hostname: message.hostname,
                    title: tabTitle,
                    activityType: actType,
                    activityState: actState,
                    confidence: confidence,
                    priority: priority,
                    progress: progress,
                    timeString: timeString,
                    activitySubtitle: subTitle,
                    glyph: glyph,
                    timestamp: message.timestamp ?? Date().timeIntervalSince1970,
                    isActiveTab: message.isActiveTab ?? true,
                    metadata: chosenActivity.metadata
                )
                activityRegistry.updateTabActivity(tabAct)
                
                if message.event == .tabActivated || message.isActiveTab == true {
                    activityRegistry.setActiveTabId(tabId, windowId: message.windowId)
                }
            }
            
            // Resolve primary activity taking background processing into account
            if let primary = activityRegistry.resolvePrimaryActivity() {
                let resolved = convertTabToUniversalActivity(primary)
                publishActivity(resolved)
            } else {
                publishActivity(chosenActivity)
            }
        }
    }
    
    private func convertTabToUniversalActivity(_ tab: ChromeTabActivity) -> UniversalAppActivity {
        var meta = tab.metadata
        if let timeStr = tab.timeString {
            meta["timeString"] = timeStr
        }
        meta["site"] = tab.siteName
        
        let subtitle: String = tab.activitySubtitle ?? {
            switch tab.activityType {
            case .processing, .generating:
                return "Processing"
            case .completed:
                return "Response Ready"
            case .editing:
                return "Editing"
            case .reading:
                return "Reading"
            case .mediaPlaying:
                return tab.timeString ?? "Playing"
            case .mediaPaused:
                return tab.timeString ?? "Paused"
            case .pageLoading:
                return "Loading"
            case .browserActive, .idle, .callActive, .composing, .failed:
                return "Working"
            }
        }()
        
        return UniversalAppActivity(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            activityType: tab.activityType == .completed ? .completed : (tab.activityType == .mediaPlaying ? .mediaPlaying : (tab.activityType == .processing ? .processing : .appActive)),
            activityTitle: tab.title,
            activitySubtitle: subtitle,
            activityState: tab.activityState == .completed ? .completed : (tab.activityState == .paused ? .paused : (tab.activityState == .playing ? .playing : .active)),
            progress: tab.progress,
            priority: tab.priority,
            confidence: tab.confidence,
            source: providerIdentifier,
            glyph: tab.glyph,
            icon: tab.glyph,
            metadata: meta
        )
    }
    
    private func publishActivity(_ activity: UniversalAppActivity) {
        lock.lock()
        currentPrimaryActivity = activity
        lock.unlock()
        
        UniversalActivityRegistry.shared.registerActivity(activity)
        onActivityPublished?(activity)
    }
    
    private func formattedProviderName(_ provider: String) -> String {
        let lower = provider.lowercased()
        if lower == "youtube" {
            return "YouTube"
        }
        if lower == "soundcloud" {
            return "SoundCloud"
        }
        if lower == "spotify" || lower == "spotify_web" {
            return "Spotify"
        }
        return provider.capitalized
    }
}

// Aliases per Phase 5 architecture
public typealias ChromeActivityProvider = ChromeMediaActivityProvider
public typealias ChromeUniversalActivityProvider = ChromeMediaActivityProvider
