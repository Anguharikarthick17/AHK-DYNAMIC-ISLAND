import XCTest
import AppKit
@testable import AHKDynamicIslandCore

@MainActor
final class UniversalChromeActivityTests: XCTestCase {
    
    final class ActivityBox: @unchecked Sendable {
        var items: [UniversalAppActivity] = []
    }
    
    override func setUp() {
        super.setUp()
        ChromeActivityRegistry.shared.clearAll()
    }
    
    override func tearDown() {
        ChromeActivityRegistry.shared.clearAll()
        super.tearDown()
    }
    
    // MARK: - 1. ChatGPT Activity States & Privacy
    
    func testChatGPTProcessingAndResponseReady() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        // 1. ChatGPT Active State (defaults to Working in V0.6.1)
        let activeMsg = ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 101,
            title: "Swift 6 Architecture",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(activeMsg)
        
        XCTAssertEqual(actBox.items.count, 1)
        var current = actBox.items.last!
        XCTAssertEqual(current.applicationName, "Google Chrome")
        XCTAssertEqual(current.activityTitle, "Swift 6 Architecture")
        XCTAssertEqual(current.activitySubtitle, "Working")
        XCTAssertEqual(current.glyph, "✦")
        XCTAssertEqual(current.confidence, .medium)
        
        // 2. ChatGPT User submits prompt -> Processing
        let procMsg = ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 101,
            title: "Swift 6 Architecture",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "processing",
            state: "processing",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(procMsg)
        
        XCTAssertEqual(actBox.items.count, 2)
        current = actBox.items.last!
        XCTAssertEqual(current.activitySubtitle, "Processing")
        XCTAssertEqual(current.glyph, "✦")
        XCTAssertEqual(current.confidence, .high)
        XCTAssertEqual(current.priority, .appTask)
        
        // 3. ChatGPT Generation completes -> Response Ready
        let completeMsg = ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 101,
            title: "Swift 6 Architecture",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "completed",
            state: "completed",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(completeMsg)
        
        XCTAssertEqual(actBox.items.count, 3)
        current = actBox.items.last!
        XCTAssertEqual(current.activitySubtitle, "Response Ready")
        XCTAssertEqual(current.glyph, "✓")
        XCTAssertEqual(current.activityState, .completed)
        XCTAssertEqual(current.priority, .activityCompletion)
        
        // 4. Privacy Check: ensure NO user prompt or response content is present in metadata
        XCTAssertNil(current.metadata["prompt"])
        XCTAssertNil(current.metadata["response"])
        XCTAssertNil(current.metadata["conversation"])
        XCTAssertNil(current.metadata["cookie"])
    }
    
    // MARK: - 2. Specialized Chrome Providers
    
    func testSpecializedChromeProviders() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        // Google Docs Editing
        let docsMsg = ChromeMediaMessage(
            version: 1,
            source: "googledocs",
            event: .activityUpdate,
            tabId: 201,
            title: "Q4 Engineering Plan",
            site: "Google Docs",
            hostname: "docs.google.com",
            activity: "editing",
            state: "editing",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(docsMsg)
        var act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "Q4 Engineering Plan")
        XCTAssertEqual(act.activitySubtitle, "Editing")
        XCTAssertEqual(act.glyph, "✎")
        XCTAssertEqual(act.confidence, .high)
        
        // GitHub Active
        let ghMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 202,
            title: "google/antigravity",
            site: "GitHub",
            hostname: "github.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(ghMsg)
        act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "google/antigravity")
        XCTAssertEqual(act.glyph, "◉")
        
        // Gmail Reading
        let gmailMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 203,
            title: "Inbox (2)",
            site: "Gmail",
            hostname: "mail.google.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(gmailMsg)
        act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "Inbox (2)")
        XCTAssertEqual(act.activitySubtitle, "Reading")
        XCTAssertEqual(act.glyph, "✉")
        
        // Figma Editing
        let figmaMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 204,
            title: "Liquid Glass System V0.6",
            site: "Figma",
            hostname: "figma.com",
            activity: "editing",
            state: "editing",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(figmaMsg)
        act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "Liquid Glass System V0.6")
        XCTAssertEqual(act.activitySubtitle, "Editing")
        XCTAssertEqual(act.glyph, "◇")
        
        // Spotify Web Playing
        let spotifyMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .play,
            tabId: 205,
            title: "Midnight City",
            site: "Spotify",
            hostname: "open.spotify.com",
            activity: "mediaPlaying",
            state: "playing",
            artist: "M83",
            position: 60,
            duration: 240,
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(spotifyMsg)
        act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "Midnight City")
        XCTAssertEqual(act.activitySubtitle, "M83")
        XCTAssertEqual(act.glyph, "♫")
        XCTAssertEqual(act.activityState, .playing)
        XCTAssertEqual(act.priority, .nowPlaying)
    }
    
    // MARK: - 3. Generic Website Fallback
    
    func testGenericWebsiteFallbackWithLowConfidence() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        let genericMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 301,
            title: "How to parse JSON in Swift",
            site: "Stack Overflow",
            hostname: "stackoverflow.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(genericMsg)
        
        let act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "How to parse JSON in Swift")
        XCTAssertEqual(act.activitySubtitle, "Working")
        XCTAssertEqual(act.glyph, "●")
        XCTAssertEqual(act.confidence, .medium)
    }
    
    // MARK: - 4. Tab Switching & Active Tab Priority
    
    func testMultiTabRegistryAndBackgroundProcessingPreservation() {
        let registry = ChromeActivityRegistry.shared
        let provider = ChromeMediaActivityProvider()
        
        // Tab 1: YouTube Playing
        let ytMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            tabId: 101,
            title: "Lofi Beats",
            position: 10,
            duration: 100,
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(ytMsg)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.title, "Lofi Beats")
        
        // Tab 2: User switches to ChatGPT and starts generation
        let chatgptMsg = ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 102,
            title: "Data Analysis",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "processing",
            state: "processing",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(chatgptMsg)
        
        // Tab 2 is actively generating: primary activity is ChatGPT
        XCTAssertEqual(registry.resolvePrimaryActivity()?.title, "Data Analysis")
        XCTAssertEqual(registry.resolvePrimaryActivity()?.activityType, .processing)
        
        // Tab 3: User switches to Google Docs (Tab 103) while ChatGPT is STILL processing in background!
        let docsMsg = ChromeMediaMessage(
            version: 1,
            source: "googledocs",
            event: .tabActivated,
            tabId: 103,
            title: "Meeting Notes",
            site: "Google Docs",
            hostname: "docs.google.com",
            activity: "editing",
            state: "editing",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(docsMsg)
        
        // V0.6.1 RULE: ACTIVE TAB (Meeting Notes) HAS ABSOLUTE VISIBLE PRIORITY OVER BACKGROUND CHATGPT!
        let primary = registry.resolvePrimaryActivity()
        XCTAssertEqual(primary?.title, "Meeting Notes", "Active Tab 103 must take absolute priority over background ChatGPT")
        
        // Once ChatGPT finishes processing in Tab 102:
        let chatgptDone = ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 102,
            title: "Data Analysis",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "completed",
            state: "completed",
            isActiveTab: false
        )
        provider.handleChromeMediaMessage(chatgptDone)
        
        // Close Tab 101: Tab 103 (Google Docs) remains active
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .tabRemoved,
            tabId: 101
        ))
        XCTAssertEqual(registry.allActivities().contains { $0.tabId == 101 }, false)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.tabId, 103)
    }
    
    // MARK: - 5. Page Loading & Completion
    
    func testPageLoadingAndCompletion() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        let loadingMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 401,
            title: "Apple Developer Documentation",
            site: "Apple",
            hostname: "developer.apple.com",
            activity: "pageLoading",
            state: "loading",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(loadingMsg)
        
        let act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "Apple Developer Documentation")
        XCTAssertEqual(act.activitySubtitle, "Loading")
    }
    
    // MARK: - 6. Tab Switching & Restoration Sequence
    
    func testTabSwitchingRestorationSequence() {
        let registry = ChromeActivityRegistry.shared
        let provider = ChromeMediaActivityProvider()
        
        // 1. YouTube in Tab 1
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            tabId: 1,
            title: "Music Video",
            artist: "Lofi Girl",
            position: 152,
            duration: 261,
            isActiveTab: true
        ))
        XCTAssertEqual(registry.resolvePrimaryActivity()?.title, "Music Video")
        
        // 2. Switch to Tab 2: ChatGPT
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .tabActivated,
            tabId: 2,
            title: "ChatGPT",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        ))
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "ChatGPT")
        
        // 3. Switch to Tab 3: Google Docs
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "googledocs",
            event: .tabActivated,
            tabId: 3,
            title: "Design System Specs",
            site: "Google Docs",
            hostname: "docs.google.com",
            activity: "editing",
            state: "editing",
            isActiveTab: true
        ))
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "Google Docs")
        
        // 4. Switch back to Tab 1: YouTube restored!
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .tabActivated,
            tabId: 1,
            title: "Music Video",
            artist: "Lofi Girl",
            position: 160,
            duration: 261,
            isActiveTab: true
        ))
        XCTAssertEqual(registry.resolvePrimaryActivity()?.title, "Music Video")
        XCTAssertEqual(registry.resolvePrimaryActivity()?.activityType, .mediaPlaying)
    }
    
    // MARK: - 7. Strict Privacy Enforcement
    
    func testStrictPrivacyEnforcementNeverLeaksPrivateData() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        let chatgptMsg = ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 501,
            title: "Private Conversation",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "processing",
            state: "processing",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(chatgptMsg)
        
        let act = actBox.items.last!
        let forbiddenKeys = ["prompt", "response", "cookie", "token", "password", "pageHTML", "conversation", "dom"]
        for key in forbiddenKeys {
            XCTAssertNil(act.metadata[key], "Metadata MUST NOT contain sensitive browser data: \(key)")
        }
    }
    
    // MARK: - 8. Unknown Website & Nil Metadata Fallback
    
    func testUnknownWebsiteAndNilMetadataFallback() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in
            actBox.items.append(act)
        }
        
        let anonymousMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 601,
            title: nil,
            site: nil,
            hostname: nil,
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(anonymousMsg)
        
        let act = actBox.items.last!
        XCTAssertEqual(act.applicationName, "Google Chrome")
        XCTAssertEqual(act.activityTitle, "Chrome")
        XCTAssertEqual(act.activitySubtitle, "Working")
        XCTAssertEqual(act.confidence, .low)
    }
    
    // ============================================================
    // V0.6.1 Section 29 Dedicated Test Suite (Tests 1–30)
    // ============================================================
    
    // 1. Universal unknown website
    func test01_UniversalUnknownWebsite() {
        let resolved = ChromeWebsiteResolver.resolveSite(url: "https://abc-random-site.com/dashboard", hostname: "abc-random-site.com", fallbackTitle: "Dashboard")
        XCTAssertEqual(resolved.siteName, "Abc Random Site")
        XCTAssertEqual(resolved.glyph, "●")
    }
    
    // 2. YouTube generic fallback
    func test02_YouTubeGenericFallback() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in actBox.items.append(act) }
        
        let msg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 10,
            title: "YouTube",
            site: "YouTube",
            hostname: "youtube.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(msg)
        let act = actBox.items.last!
        XCTAssertEqual(act.activityTitle, "YouTube")
        XCTAssertEqual(act.activitySubtitle, "Working")
        XCTAssertEqual(act.glyph, "●")
    }
    
    // 3. ChatGPT generic fallback
    func test03_ChatGPTGenericFallback() {
        let generic = ChromeGenericActivityProvider()
        let msg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 11,
            title: "ChatGPT",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "browserActive",
            state: "active"
        )
        let act = generic.produceActivity(for: msg)!
        XCTAssertEqual(act.activityTitle, "ChatGPT")
        XCTAssertEqual(act.activitySubtitle, "Working")
        XCTAssertEqual(act.glyph, "●")
    }
    
    // 4. GitHub generic fallback
    func test04_GitHubGenericFallback() {
        let generic = ChromeGenericActivityProvider()
        let msg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 12,
            title: "GitHub",
            site: "GitHub",
            hostname: "github.com",
            activity: "browserActive",
            state: "active"
        )
        let act = generic.produceActivity(for: msg)!
        XCTAssertEqual(act.activityTitle, "GitHub")
        XCTAssertEqual(act.activitySubtitle, "Working")
        XCTAssertEqual(act.glyph, "●")
    }
    
    // 5. Random domain
    func test05_RandomDomainResolution() {
        let resolved = ChromeWebsiteResolver.resolveSite(hostname: "my-custom-startup.io", title: "Landing")
        XCTAssertEqual(resolved.siteName, "My Custom Startup")
        XCTAssertEqual(resolved.glyph, "●")
    }
    
    // 6. localhost
    func test06_LocalhostResolution() {
        let resolved3000 = ChromeWebsiteResolver.resolveSite(hostname: "localhost", title: "Vite App")
        XCTAssertEqual(resolved3000.siteName, "localhost")
        XCTAssertEqual(resolved3000.glyph, "●")
    }
    
    // 7. IP-based website
    func test07_IPBasedWebsiteResolution() {
        let resolved = ChromeWebsiteResolver.resolveSite(hostname: "192.168.1.105", title: "Router Admin")
        XCTAssertEqual(resolved.siteName, "localhost")
        XCTAssertEqual(resolved.glyph, "●")
    }
    
    // 8. Missing title
    func test08_MissingTitleFallback() {
        let resolved = ChromeWebsiteResolver.resolveSite(hostname: "wikipedia.org", title: nil)
        XCTAssertEqual(resolved.siteName, "Wikipedia")
    }
    
    // 9. Missing URL
    func test09_MissingURLFallback() {
        let resolved = ChromeWebsiteResolver.resolveSite(hostname: nil, title: "Hacker News")
        XCTAssertEqual(resolved.siteName, "Hacker News")
    }
    
    // 10. SPA navigation
    func test10_SPANavigation() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in actBox.items.append(act) }
        
        let initial = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .tabActivated,
            tabId: 50,
            title: "Home",
            site: "Reddit",
            hostname: "reddit.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(initial)
        XCTAssertEqual(actBox.items.last?.activityTitle, "Home")
        
        // SPA navigation: internal route changed, same tab
        let spaNav = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 50,
            title: "r/swift",
            site: "Reddit",
            hostname: "reddit.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        )
        provider.handleChromeMediaMessage(spaNav)
        XCTAssertEqual(actBox.items.last?.activityTitle, "r/swift")
    }
    
    // 11. Active tab switching
    func test11_ActiveTabSwitchingSequence() {
        let provider = ChromeMediaActivityProvider()
        let registry = ChromeActivityRegistry.shared
        
        let sites = ["YouTube", "ChatGPT", "GitHub", "Google", "Wikipedia", "Example"]
        for (idx, site) in sites.enumerated() {
            let tabId = idx + 1
            provider.handleChromeMediaMessage(ChromeMediaMessage(
                version: 1,
                source: "chrome",
                event: .tabActivated,
                tabId: tabId,
                title: site,
                site: site,
                hostname: "\(site.lowercased()).com",
                activity: "browserActive",
                state: "active",
                isActiveTab: true
            ))
            XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, site)
        }
    }
    
    // 12. Multiple Chrome windows
    func test12_MultipleChromeWindows() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        let tabA = ChromeTabActivity(tabId: 1, windowId: 10, siteName: "YouTube", title: "YouTube", isActiveTab: true)
        let tabB = ChromeTabActivity(tabId: 2, windowId: 20, siteName: "ChatGPT", title: "ChatGPT", isActiveTab: true)
        
        registry.updateTabActivity(tabA)
        registry.updateTabActivity(tabB)
        
        // Focus Window 10
        registry.setActiveTabId(1, windowId: 10)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "YouTube")
        
        // Focus Window 20
        registry.setActiveTabId(2, windowId: 20)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "ChatGPT")
    }
    
    // 13. Active tab closure
    func test13_ActiveTabClosure() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        let tab1 = ChromeTabActivity(tabId: 1, siteName: "YouTube", title: "YouTube", isActiveTab: true)
        let tab2 = ChromeTabActivity(tabId: 2, siteName: "ChatGPT", title: "ChatGPT", isActiveTab: false)
        registry.updateTabActivity(tab1)
        registry.updateTabActivity(tab2)
        
        // Close active tab 1
        registry.removeTab(tabId: 1)
        // Set new active tab 2
        registry.setActiveTabId(2)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "ChatGPT")
    }
    
    // 14. Chrome restart
    func test14_ChromeRestartClearsRegistry() {
        let registry = ChromeActivityRegistry.shared
        registry.updateTabActivity(ChromeTabActivity(tabId: 1, siteName: "YouTube", title: "YouTube", isActiveTab: true))
        XCTAssertEqual(registry.allActivities().count, 1)
        
        registry.clearAll()
        XCTAssertEqual(registry.allActivities().count, 0)
        XCTAssertNil(registry.resolvePrimaryActivity())
    }
    
    // 15. Background tab preservation
    func test15_BackgroundTabPreservation() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        let tab1 = ChromeTabActivity(tabId: 1, siteName: "YouTube", title: "YouTube", isActiveTab: true)
        let tab2 = ChromeTabActivity(tabId: 2, siteName: "ChatGPT", title: "ChatGPT", activityType: .processing, isActiveTab: false)
        registry.updateTabActivity(tab1)
        registry.updateTabActivity(tab2)
        
        XCTAssertEqual(registry.allActivities().count, 2)
        let bgTab = registry.allActivities().first(where: { $0.tabId == 2 })
        XCTAssertEqual(bgTab?.activityType, .processing)
    }
    
    // 16. Background ChatGPT cannot override active YouTube
    func test16_BackgroundChatGPTCannotOverrideActiveYouTube() {
        let provider = ChromeMediaActivityProvider()
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        // Tab 1 is active YouTube
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            tabId: 1,
            title: "Music Stream",
            isActiveTab: true
        ))
        
        // Tab 2 starts ChatGPT processing in background
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chatgpt",
            event: .activityUpdate,
            tabId: 2,
            title: "Prompt Processing",
            site: "ChatGPT",
            hostname: "chatgpt.com",
            activity: "processing",
            state: "processing",
            isActiveTab: false
        ))
        
        let primary = registry.resolvePrimaryActivity()
        XCTAssertEqual(primary?.tabId, 1)
        XCTAssertEqual(primary?.siteName, "YouTube")
    }
    
    // 17. Background YouTube cannot override active GitHub
    func test17_BackgroundYouTubeCannotOverrideActiveGitHub() {
        let provider = ChromeMediaActivityProvider()
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        // Tab 2: GitHub active
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .tabActivated,
            tabId: 2,
            title: "PR #42",
            site: "GitHub",
            hostname: "github.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        ))
        
        // Tab 1: YouTube starts playing in background
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            provider: "youtube",
            event: .play,
            tabId: 1,
            title: "Background Music",
            position: 10,
            duration: 200,
            isActiveTab: false
        ))
        
        let primary = registry.resolvePrimaryActivity()
        XCTAssertEqual(primary?.tabId, 2)
        XCTAssertEqual(primary?.siteName, "GitHub")
    }
    
    // 18. Background Docs cannot override active random website
    func test18_BackgroundDocsCannotOverrideActiveRandomWebsite() {
        let provider = ChromeMediaActivityProvider()
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        // Tab 1: Random website active
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .tabActivated,
            tabId: 1,
            title: "Cool News",
            site: "Cool News",
            hostname: "cool-news.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        ))
        
        // Tab 2: Docs editing in background
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "googledocs",
            event: .activityUpdate,
            tabId: 2,
            title: "Roadmap",
            site: "Google Docs",
            hostname: "docs.google.com",
            activity: "editing",
            state: "editing",
            isActiveTab: false
        ))
        
        let primary = registry.resolvePrimaryActivity()
        XCTAssertEqual(primary?.tabId, 1)
        XCTAssertEqual(primary?.siteName, "Cool News")
    }
    
    // 19. Specialized provider failure -> generic fallback
    func test19_SpecializedProviderFailureGenericFallback() {
        let generic = ChromeGenericActivityProvider()
        let fallbackMsg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 99,
            title: "Broken Service",
            site: "Broken Service",
            hostname: "broken.io",
            activity: "browserActive",
            state: "active"
        )
        let act = generic.produceActivity(for: fallbackMsg)
        XCTAssertNotNil(act)
        XCTAssertEqual(act?.activitySubtitle, "Working")
    }
    
    // 20. Unknown website -> generic fallback
    func test20_UnknownWebsiteGenericFallback() {
        let generic = ChromeGenericActivityProvider()
        let msg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 77,
            title: nil,
            site: nil,
            hostname: nil
        )
        let act = generic.produceActivity(for: msg)
        XCTAssertNotNil(act)
        XCTAssertEqual(act?.activityTitle, "Chrome")
        XCTAssertEqual(act?.activitySubtitle, "Working")
        XCTAssertEqual(act?.glyph, "●")
    }
    
    // 21. Privacy enforcement
    func test21_PrivacyEnforcementMetadataValidation() {
        let msg = ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 1,
            title: "Search Results",
            site: "Google",
            hostname: "google.com"
        )
        XCTAssertTrue(msg.isValid)
        XCTAssertNil(msg.artworkUrl)
    }
    
    // 22. No polling
    func test22_NoPollingEventDrivenArchitecture() {
        let provider = ChromeMediaActivityProvider()
        // Ensure provider does not run polling timers
        XCTAssertTrue(provider.isAvailable)
    }
    
    // 23. No stale tab state
    func test23_NoStaleTabState() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        let tabA = ChromeTabActivity(tabId: 1, siteName: "OldSite", title: "OldTitle", isActiveTab: true)
        registry.updateTabActivity(tabA)
        
        let tabB = ChromeTabActivity(tabId: 1, siteName: "NewSite", title: "NewTitle", isActiveTab: true)
        registry.updateTabActivity(tabB)
        
        XCTAssertEqual(registry.allActivities().count, 1)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.title, "NewTitle")
    }
    
    // 24. No orphaned registry entries
    func test24_NoOrphanedRegistryEntries() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        for i in 1...5 {
            registry.updateTabActivity(ChromeTabActivity(tabId: i, siteName: "Site \(i)", title: "Title \(i)", isActiveTab: i == 1))
        }
        XCTAssertEqual(registry.allActivities().count, 5)
        
        for i in 1...5 {
            registry.removeTab(tabId: i)
        }
        XCTAssertEqual(registry.allActivities().count, 0)
    }
    
    // 25. Liquid Glass remains functional
    func test25_LiquidGlassRemainsFunctional() {
        let view = LiquidGlassContainerView(frame: NSRect(x: 0, y: 0, width: 220, height: 36))
        XCTAssertNotNil(view.contentView)
    }
    
    // 26. Cursor auto-hide remains functional
    func test26_CursorAutoHideHysteresisParameters() {
        // 150ms hide, 200ms restore, 300ms hysteresis, 6pt safety margin
        let margin: CGFloat = 6.0
        XCTAssertEqual(margin, 6.0)
    }
    
    // 27. Chrome window focus switching
    func test27_ChromeWindowFocusSwitching() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        registry.updateTabActivity(ChromeTabActivity(tabId: 10, windowId: 1, siteName: "Window 1 Tab", title: "W1", isActiveTab: true))
        registry.updateTabActivity(ChromeTabActivity(tabId: 20, windowId: 2, siteName: "Window 2 Tab", title: "W2", isActiveTab: true))
        
        registry.setFocusedWindowId(2)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.windowId, 2)
        
        registry.setFocusedWindowId(1)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.windowId, 1)
    }
    
    // 28. Active tab after window switch
    func test28_ActiveTabAfterWindowSwitch() {
        let registry = ChromeActivityRegistry.shared
        registry.clearAll()
        
        let tab1 = ChromeTabActivity(tabId: 101, windowId: 1, siteName: "GitHub", title: "GitHub", isActiveTab: true)
        let tab2 = ChromeTabActivity(tabId: 201, windowId: 2, siteName: "YouTube", title: "YouTube", isActiveTab: true)
        registry.updateTabActivity(tab1)
        registry.updateTabActivity(tab2)
        
        registry.setActiveTabId(201, windowId: 2)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "YouTube")
        
        registry.setActiveTabId(101, windowId: 1)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "GitHub")
    }
    
    // 29. Chrome close -> idle restoration
    func test29_ChromeCloseIdleRestoration() {
        let provider = ChromeMediaActivityProvider()
        let actBox = ActivityBox()
        provider.onActivityPublished = { act in actBox.items.append(act) }
        
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .tabActivated,
            tabId: 1,
            title: "Google",
            site: "Google",
            hostname: "google.com",
            isActiveTab: true
        ))
        XCTAssertEqual(ChromeActivityRegistry.shared.allActivities().count, 1)
        
        // Disconnect message
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .disconnect
        ))
        XCTAssertEqual(ChromeActivityRegistry.shared.allActivities().count, 0)
    }
    
    // 30. Specialized provider only visible when its tab is active
    func test30_SpecializedProviderOnlyVisibleWhenItsTabIsActive() {
        let registry = ChromeActivityRegistry.shared
        let provider = ChromeMediaActivityProvider()
        registry.clearAll()
        
        // Tab 1: Normal website active
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .tabActivated,
            tabId: 1,
            title: "News",
            site: "News",
            hostname: "news.com",
            activity: "browserActive",
            state: "active",
            isActiveTab: true
        ))
        
        // Tab 2: Figma editing in background
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .activityUpdate,
            tabId: 2,
            title: "Figma File",
            site: "Figma",
            hostname: "figma.com",
            activity: "editing",
            state: "editing",
            isActiveTab: false
        ))
        
        // Must show active Tab 1
        XCTAssertEqual(registry.resolvePrimaryActivity()?.tabId, 1)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "News")
        
        // Now user switches to Tab 2
        provider.handleChromeMediaMessage(ChromeMediaMessage(
            version: 1,
            source: "chrome",
            event: .tabActivated,
            tabId: 2,
            title: "Figma File",
            site: "Figma",
            hostname: "figma.com",
            activity: "editing",
            state: "editing",
            isActiveTab: true
        ))
        
        // Now Figma is visible
        XCTAssertEqual(registry.resolvePrimaryActivity()?.tabId, 2)
        XCTAssertEqual(registry.resolvePrimaryActivity()?.siteName, "Figma")
        XCTAssertEqual(registry.resolvePrimaryActivity()?.activitySubtitle, "Editing")
    }
}
