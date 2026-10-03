import Foundation

/// Protocol for specialized website activity providers within Chrome.
public protocol ChromeSubActivityProvider: Sendable {
    var providerIdentifier: String { get }
    func canHandle(message: ChromeMediaMessage) -> Bool
    func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity?
}

// MARK: - 1. ChatGPT Provider (Phase 7 & 8)

public final class ChatGPTActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.chatgpt"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        let site = message.site?.lowercased() ?? ""
        let host = message.hostname?.lowercased() ?? ""
        let source = message.source.lowercased()
        return site.contains("chatgpt") || host.contains("chatgpt.com") || host.contains("chat.openai.com") || source == "chatgpt"
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let title = (message.title != nil && !message.title!.isEmpty && message.title != "ChatGPT") ? message.title! : "ChatGPT"
        let state = message.state?.lowercased() ?? message.activity?.lowercased() ?? "active"
        
        var glyph = "✦"
        var subtitle = "Active"
        var actType = UniversalActivityType.appActive
        var actState = UniversalActivityState.active
        var priority = ActivityPriority.appActive
        var confidence = ActivityConfidence.medium
        
        if state == "processing" || state == "generating" || message.event == .stateChange && message.state == "processing" {
            glyph = "✦"
            subtitle = "Processing"
            actType = .processing
            actState = .active
            priority = .appTask
            confidence = .high
        } else if state == "completed" || message.state == "completed" {
            glyph = "✓"
            subtitle = "Response Ready"
            actType = .completed
            actState = .completed
            priority = .activityCompletion
            confidence = .high
        } else {
            glyph = "✦"
            subtitle = "Working"
            actType = .appActive
            actState = .active
            priority = .appActive
            confidence = .medium
        }
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: actType,
            activityTitle: title,
            activitySubtitle: subtitle,
            activityState: actState,
            priority: priority,
            confidence: confidence,
            source: providerIdentifier,
            glyph: glyph,
            icon: glyph,
            metadata: [
                "site": "ChatGPT",
                "state": state
            ]
        )
    }
}

// MARK: - 2. Google Docs Provider (Phase 9)

public final class GoogleDocsActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.googledocs"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        let site = message.site?.lowercased() ?? ""
        let host = message.hostname?.lowercased() ?? ""
        let source = message.source.lowercased()
        return site.contains("google docs") || host.contains("docs.google.com") || source == "googledocs"
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let title = message.title ?? "Google Docs"
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: .appActive,
            activityTitle: title,
            activitySubtitle: "Editing",
            activityState: .active,
            priority: .appTask,
            confidence: .high,
            source: providerIdentifier,
            glyph: "✎",
            icon: "✎",
            metadata: [
                "site": "Google Docs",
                "state": "editing"
            ]
        )
    }
}

// MARK: - 3. GitHub Provider (Phase 9)

public final class GitHubActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.github"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        let site = message.site?.lowercased() ?? ""
        let host = message.hostname?.lowercased() ?? ""
        return site.contains("github") || host.contains("github.com")
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let title = message.title ?? "GitHub"
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: .appActive,
            activityTitle: title,
            activitySubtitle: "Active",
            activityState: .active,
            priority: .appActive,
            confidence: .medium,
            source: providerIdentifier,
            glyph: "◉",
            icon: "◉",
            metadata: [
                "site": "GitHub",
                "state": "active"
            ]
        )
    }
}

// MARK: - 4. Gmail Provider (Phase 9)

public final class GmailActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.gmail"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        let site = message.site?.lowercased() ?? ""
        let host = message.hostname?.lowercased() ?? ""
        return site.contains("gmail") || host.contains("mail.google.com")
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let title = message.title ?? "Gmail"
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: .appActive,
            activityTitle: title,
            activitySubtitle: "Reading",
            activityState: .active,
            priority: .appActive,
            confidence: .medium,
            source: providerIdentifier,
            glyph: "✉",
            icon: "✉",
            metadata: [
                "site": "Gmail",
                "state": "reading"
            ]
        )
    }
}

// MARK: - 5. Figma Provider (Phase 9)

public final class FigmaActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.figma"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        let site = message.site?.lowercased() ?? ""
        let host = message.hostname?.lowercased() ?? ""
        return site.contains("figma") || host.contains("figma.com")
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let title = message.title ?? "Figma"
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: .appActive,
            activityTitle: title,
            activitySubtitle: "Editing",
            activityState: .active,
            priority: .appTask,
            confidence: .high,
            source: providerIdentifier,
            glyph: "◇",
            icon: "◇",
            metadata: [
                "site": "Figma",
                "state": "editing"
            ]
        )
    }
}

// MARK: - 6. Spotify Web Provider (Phase 9)

public final class SpotifyWebActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.spotify"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        let site = message.site?.lowercased() ?? ""
        let host = message.hostname?.lowercased() ?? ""
        let provider = message.provider.lowercased()
        return site.contains("spotify") || host.contains("spotify.com") || provider.contains("spotify")
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let title = message.title ?? "Spotify"
        let isPaused = (message.event == .pause || message.state == "paused")
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: isPaused ? .mediaPaused : .mediaPlaying,
            activityTitle: title,
            activitySubtitle: message.artist ?? "Playing",
            activityState: isPaused ? .paused : .playing,
            progress: message.progress,
            priority: .nowPlaying,
            confidence: .high,
            source: providerIdentifier,
            glyph: isPaused ? "⏸" : "♫",
            icon: isPaused ? "⏸" : "♫",
            metadata: [
                "site": "Spotify",
                "provider": "spotify",
                "timeString": message.formattedTimeString ?? ""
            ]
        )
    }
}

// MARK: - 7. Generic Chrome Fallback Provider (Phase 6)

public final class ChromeGenericActivityProvider: ChromeSubActivityProvider, @unchecked Sendable {
    public let providerIdentifier: String = "com.ahk.provider.chrome.generic"
    
    public init() {}
    
    public func canHandle(message: ChromeMediaMessage) -> Bool {
        return true // Fallback matches all messages
    }
    
    public func produceActivity(for message: ChromeMediaMessage) -> UniversalAppActivity? {
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let resolved = ChromeWebsiteResolver.resolveSite(url: nil, hostname: message.hostname, fallbackTitle: message.title)
        let siteName = message.site ?? resolved.siteName
        let title = (message.title != nil && !message.title!.isEmpty && message.title != "Active" && message.title != "Working") ? message.title! : siteName
        
        let isLoading = (message.activity == "pageLoading" || message.event == .activityUpdate && message.state == "loading")
        let glyph = isLoading ? "◌" : (message.glyph ?? "●")
        let subtitle = isLoading ? "Loading" : (message.activitySubtitle ?? "Working")
        
        return UniversalAppActivity(
            applicationName: appName,
            bundleIdentifier: bundleID,
            activityType: .appActive,
            activityTitle: title,
            activitySubtitle: subtitle,
            activityState: .active,
            priority: .appActive,
            confidence: (siteName == "Chrome") ? .low : .medium,
            source: providerIdentifier,
            glyph: glyph,
            icon: glyph,
            metadata: [
                "site": siteName,
                "generic": "true"
            ]
        )
    }
}
