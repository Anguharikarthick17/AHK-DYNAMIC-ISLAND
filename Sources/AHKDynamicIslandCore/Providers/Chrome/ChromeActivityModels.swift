import Foundation

/// Specific playback or tab lifecycle event emitted by the Chrome extension.
public enum ChromeMediaEvent: String, Codable, Sendable, Equatable {
    case play
    case pause
    case timeupdate
    case ended
    case disconnect
    case activityUpdate
    case tabActivated
    case tabRemoved
    case stateChange
    case other
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ChromeMediaEvent(rawValue: raw) ?? .other
    }
}

/// Normalized Chrome activity classification per Section 4.
public enum ChromeActivityType: String, Codable, Sendable, Equatable {
    case browserActive
    case pageLoading
    case mediaPlaying
    case mediaPaused
    case processing
    case generating
    case editing
    case composing
    case reading
    case callActive
    case completed
    case failed
    case idle
    
    public var defaultGlyph: String {
        switch self {
        case .mediaPlaying: return "▶"
        case .mediaPaused: return "⏸"
        case .processing, .generating: return "✦"
        case .editing, .composing: return "✎"
        case .reading: return "✉"
        case .callActive: return "📞"
        case .completed: return "✓"
        case .failed: return "⚠"
        case .pageLoading: return "◌"
        case .browserActive, .idle: return "●"
        }
    }
}

/// Normalized Chrome activity state per Section 4.
public enum ChromeActivityState: String, Codable, Sendable, Equatable {
    case active
    case processing
    case generating
    case playing
    case paused
    case editing
    case reading
    case loading
    case completed
    case idle
}

/// In-memory model representing the state of an individual Chrome tab.
public struct ChromeTabActivity: Sendable, Equatable {
    public let tabId: Int
    public let windowId: Int?
    public let applicationName: String
    public let siteName: String
    public let hostname: String?
    public let title: String
    public let activityType: ChromeActivityType
    public let activityState: ChromeActivityState
    public let confidence: ActivityConfidence
    public let priority: ActivityPriority
    public let progress: Double?
    public let timeString: String?
    public let activitySubtitle: String?
    public let glyph: String
    public let timestamp: Double
    public let isActiveTab: Bool
    public let metadata: [String: String]
    
    public init(
        tabId: Int,
        windowId: Int? = nil,
        applicationName: String = "Google Chrome",
        siteName: String,
        hostname: String? = nil,
        title: String,
        activityType: ChromeActivityType = .browserActive,
        activityState: ChromeActivityState = .active,
        confidence: ActivityConfidence = .low,
        priority: ActivityPriority = .appActive,
        progress: Double? = nil,
        timeString: String? = nil,
        activitySubtitle: String? = nil,
        glyph: String? = nil,
        timestamp: Double = Date().timeIntervalSince1970,
        isActiveTab: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.tabId = tabId
        self.windowId = windowId
        self.applicationName = applicationName
        self.siteName = siteName
        self.hostname = hostname
        self.title = title
        self.activityType = activityType
        self.activityState = activityState
        self.confidence = confidence
        self.priority = priority
        self.progress = progress
        self.timeString = timeString
        self.activitySubtitle = activitySubtitle
        self.glyph = glyph ?? activityType.defaultGlyph
        self.timestamp = timestamp
        self.isActiveTab = isActiveTab
        self.metadata = metadata
    }
}

/// Strongly-typed schema for messages received from Chrome Native Messaging.
/// Compatible with both V0.5.2 media messages and V0.6 universal activity messages.
public struct ChromeMediaMessage: Codable, Sendable, Equatable {
    public let version: Int
    public let source: String
    public let provider: String
    public let event: ChromeMediaEvent
    public let sessionId: String?
    public let title: String?
    public let artist: String?
    public let position: Double?
    public let duration: Double?
    public let timestamp: Double?
    public let artworkUrl: String?
    
    // V0.6 Universal Activity fields
    public let tabId: Int?
    public let windowId: Int?
    public let site: String?
    public let hostname: String?
    public let activity: String?
    public let state: String?
    public let activitySubtitle: String?
    public let confidenceLevel: String?
    public let isActiveTab: Bool?
    public let glyph: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case source
        case provider
        case event
        case sessionId
        case title
        case artist
        case position
        case duration
        case timestamp
        case artworkUrl
        case tabId
        case windowId
        case site
        case hostname
        case activity
        case state
        case activitySubtitle
        case confidenceLevel = "confidence"
        case isActiveTab
        case glyph
    }
    
    // 1. Universal Tab Activity Initializer
    public init(
        version: Int = 1,
        source: String = "chrome",
        provider: String = "youtube",
        event: ChromeMediaEvent = .activityUpdate,
        tabId: Int? = nil,
        windowId: Int? = nil,
        title: String? = nil,
        site: String? = nil,
        hostname: String? = nil,
        activity: String? = nil,
        state: String? = nil,
        activitySubtitle: String? = nil,
        artist: String? = nil,
        position: Double? = nil,
        duration: Double? = nil,
        confidenceLevel: String? = nil,
        isActiveTab: Bool? = nil,
        glyph: String? = nil,
        timestamp: Double? = Date().timeIntervalSince1970,
        artworkUrl: String? = nil,
        sessionId: String? = nil
    ) {
        self.version = version
        self.source = source
        self.provider = provider
        self.event = event
        self.sessionId = sessionId
        self.title = title
        self.artist = artist
        self.position = position
        self.duration = duration
        self.timestamp = timestamp
        self.artworkUrl = artworkUrl
        self.tabId = tabId
        self.windowId = windowId
        self.site = site
        self.hostname = hostname
        self.activity = activity
        self.state = state
        self.activitySubtitle = activitySubtitle
        self.confidenceLevel = confidenceLevel
        self.isActiveTab = isActiveTab
        self.glyph = glyph
    }
    
    // 2. Backward-compatible Media Initializer (V0.5.2)
    public init(
        version: Int = 1,
        source: String = "chrome",
        provider: String = "youtube",
        event: ChromeMediaEvent = .play,
        sessionId: String? = nil,
        title: String? = nil,
        artist: String? = nil,
        position: Double? = nil,
        duration: Double? = nil,
        timestamp: Double? = Date().timeIntervalSince1970,
        artworkUrl: String? = nil
    ) {
        self.version = version
        self.source = source
        self.provider = provider
        self.event = event
        self.sessionId = sessionId
        self.title = title
        self.artist = artist
        self.position = position
        self.duration = duration
        self.timestamp = timestamp
        self.artworkUrl = artworkUrl
        self.tabId = nil
        self.windowId = nil
        self.site = nil
        self.hostname = nil
        self.activity = nil
        self.state = nil
        self.activitySubtitle = nil
        self.confidenceLevel = nil
        self.isActiveTab = nil
        self.glyph = nil
    }
    
    /// Decodes message from JSON with backwards compatibility.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? "chrome"
        self.provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? (try container.decodeIfPresent(String.self, forKey: .site)?.lowercased() ?? "chrome")
        self.event = try container.decodeIfPresent(ChromeMediaEvent.self, forKey: .event) ?? .activityUpdate
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
        self.position = try container.decodeIfPresent(Double.self, forKey: .position)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        self.timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp)
        self.artworkUrl = try container.decodeIfPresent(String.self, forKey: .artworkUrl)
        self.tabId = try container.decodeIfPresent(Int.self, forKey: .tabId)
        self.windowId = try container.decodeIfPresent(Int.self, forKey: .windowId)
        self.site = try container.decodeIfPresent(String.self, forKey: .site)
        self.hostname = try container.decodeIfPresent(String.self, forKey: .hostname)
        self.activity = try container.decodeIfPresent(String.self, forKey: .activity)
        self.state = try container.decodeIfPresent(String.self, forKey: .state)
        self.activitySubtitle = try container.decodeIfPresent(String.self, forKey: .activitySubtitle)
        self.confidenceLevel = try container.decodeIfPresent(String.self, forKey: .confidenceLevel)
        self.isActiveTab = try container.decodeIfPresent(Bool.self, forKey: .isActiveTab)
        self.glyph = try container.decodeIfPresent(String.self, forKey: .glyph)
    }
    
    /// Validates message integrity according to Section 8, 9, 10, and 18.
    public var isValid: Bool {
        guard version == 1 else { return false }
        let validSources = ["chrome", "chatgpt", "googledocs", "youtube", "spotify"]
        guard validSources.contains(source.lowercased()) else { return false }
        
        if let pos = position, (pos < 0 || pos.isNaN || pos.isInfinite) {
            return false
        }
        if let dur = duration, (dur < 0 || dur.isNaN || dur.isInfinite) {
            return false
        }
        
        return true
    }
    
    /// Normalized progress value between 0.0 and 1.0.
    public var progress: Double? {
        guard let pos = position, let dur = duration, dur > 0 else { return nil }
        return min(max(pos / dur, 0.0), 1.0)
    }
    
    /// Formatted time string (e.g. "2:34" or "2:34 / 5:12").
    public var formattedTimeString: String? {
        guard let pos = position else { return nil }
        let posStr = Self.formatSeconds(pos)
        if let dur = duration, dur > 0 {
            let durStr = Self.formatSeconds(dur)
            return "\(posStr) / \(durStr)"
        }
        return posStr
    }
    
    public static func formatSeconds(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public static func decode(from data: Data) -> ChromeMediaMessage? {
        return try? JSONDecoder().decode(ChromeMediaMessage.self, from: data)
    }
    
    public func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
}

/// Centralized website identity resolver for universal Chrome tab support (Section 9).
public struct ChromeWebsiteResolver: Sendable {
    public static func resolveSite(hostname: String?, title: String?) -> (siteName: String, glyph: String) {
        let host = (hostname ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "www.", with: "")
        
        // 1. Localhost & IP Addresses
        if host == "localhost" || host.hasPrefix("localhost:") || host == "127.0.0.1" || host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            return ("localhost", "●")
        }
        
        // 2. Recognized Hostnames / Services
        if host.hasSuffix("youtube.com") { return ("YouTube", "●") }
        if host.hasSuffix("chatgpt.com") || host.hasSuffix("chat.openai.com") { return ("ChatGPT", "✦") }
        if host == "docs.google.com" { return ("Google Docs", "✎") }
        if host == "mail.google.com" { return ("Gmail", "✉") }
        if host.contains("google.") { return ("Google", "●") }
        if host.hasSuffix("github.com") { return ("GitHub", "◉") }
        if host.hasSuffix("figma.com") { return ("Figma", "◇") }
        if host.hasSuffix("spotify.com") { return ("Spotify", "♫") }
        if host.hasSuffix("instagram.com") { return ("Instagram", "●") }
        if host.hasSuffix("whatsapp.com") { return ("WhatsApp", "●") }
        if host.hasSuffix("x.com") || host.hasSuffix("twitter.com") { return ("X", "●") }
        if host.contains("amazon.") { return ("Amazon", "●") }
        if host.hasSuffix("netflix.com") { return ("Netflix", "●") }
        if host.hasSuffix("wikipedia.org") { return ("Wikipedia", "●") }
        if host.hasSuffix("stackoverflow.com") { return ("Stack Overflow", "●") }
        if host.hasSuffix("linkedin.com") { return ("LinkedIn", "●") }
        if host.hasSuffix("reddit.com") { return ("Reddit", "●") }
        
        // 3. Clean Domain-Derived Name
        if host.contains(".") {
            let parts = host.split(separator: ".").map(String.init)
            let commonTlds: Set<String> = ["com", "org", "net", "edu", "gov", "mil", "io", "app", "dev", "ai", "co", "uk", "ca", "de", "jp", "fr", "au", "in", "us"]
            var mainIndex = parts.count - 2
            if mainIndex > 0 && commonTlds.contains(parts[parts.count - 1]) && commonTlds.contains(parts[parts.count - 2]) {
                mainIndex = parts.count - 3
            }
            if mainIndex >= 0 && mainIndex < parts.count {
                let label = parts[mainIndex]
                let words = label.components(separatedBy: CharacterSet(charactersIn: "-_")).filter { !$0.isEmpty }
                if !words.isEmpty {
                    let siteName = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
                    return (siteName, "●")
                }
            }
        }
        
        // 4. Fallback to Title or "Chrome"
        if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let clean = t.replacingOccurrences(of: "^\\([0-9]+\\)\\s*", with: "", options: .regularExpression)
                         .components(separatedBy: CharacterSet(charactersIn: "-–—·|•"))[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && clean.count <= 25 {
                return (clean, "●")
            }
        }
        
        return ("Chrome", "●")
    }
    
    public static func resolveSite(url: String? = nil, hostname: String? = nil, fallbackTitle: String? = nil) -> (siteName: String, glyph: String) {
        var host = (hostname ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "www.", with: "")
        if host.isEmpty, let urlStr = url, let parsed = URL(string: urlStr), let h = parsed.host {
            host = h.lowercased().replacingOccurrences(of: "www.", with: "")
        }
        let res = resolveSite(hostname: host, title: fallbackTitle)
        return (res.siteName, res.glyph)
    }
}

