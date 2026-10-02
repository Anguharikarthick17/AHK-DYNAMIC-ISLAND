import AppKit
import Foundation

/// Activity classification types supported by the universal activity system.
public enum UniversalActivityType: String, Equatable, Sendable {
    case appActive
    case appInactive
    case mediaPlaying
    case mediaPaused
    case download
    case upload
    case fileTransfer
    case building
    case processing
    case rendering
    case exporting
    case installing
    case syncing
    case notification
    case timer
    case completed
    case error
    case custom
    
    /// Whether this activity is an ongoing persistent process (e.g. building, rendering, playing).
    public var isOngoing: Bool {
        switch self {
        case .mediaPlaying, .building, .processing, .rendering, .exporting, .installing, .syncing, .upload, .download:
            return true
        default:
            return false
        }
    }
    
    /// Default glyph/symbol representing the activity type.
    public var defaultGlyph: String {
        switch self {
        case .appActive:
            return "●"
        case .appInactive:
            return "○"
        case .mediaPlaying:
            return "▶"
        case .mediaPaused:
            return "⏸"
        case .download:
            return "↓"
        case .upload:
            return "↑"
        case .fileTransfer:
            return "⇄"
        case .building:
            return "⚒"
        case .processing:
            return "⚙"
        case .rendering:
            return "◉"
        case .exporting:
            return "⇪"
        case .installing:
            return "⤓"
        case .syncing:
            return "↻"
        case .notification:
            return "🔔"
        case .timer:
            return "⏱"
        case .completed:
            return "✓"
        case .error:
            return "⚠"
        case .custom:
            return "✦"
        }
    }
}

/// Confidence rating for detected application activity.
/// HIGH: macOS publicly exposes the exact activity (e.g. Media Now Playing, explicit cooperate event).
/// MEDIUM: activity can reasonably be determined through public system signals.
/// LOW: only generic application identity/active state is known. Never turn weak signals into fake precision.
public enum ActivityConfidence: Int, Equatable, Comparable, Sendable {
    case low = 1
    case medium = 2
    case high = 3
    
    public static func < (lhs: ActivityConfidence, rhs: ActivityConfidence) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var displayName: String {
        switch self {
        case .low:
            return "Generic Identity"
        case .medium:
            return "Inferred Public Signal"
        case .high:
            return "Exact Public Telemetry"
        }
    }
}

/// Information about an application discovered dynamically at runtime.
public struct DiscoveredApplication: Equatable, Sendable {
    public let applicationName: String
    public let bundleIdentifier: String
    public let processIdentifier: pid_t
    public let isActive: Bool
    public let launchDate: Date?
    
    public init(
        applicationName: String,
        bundleIdentifier: String,
        processIdentifier: pid_t = 0,
        isActive: Bool = true,
        launchDate: Date? = nil
    ) {
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.isActive = isActive
        self.launchDate = launchDate
    }
}

/// Unified model representing an application activity across macOS.
public struct UniversalAppActivity: Equatable, Sendable {
    public let applicationName: String
    public let bundleIdentifier: String
    public let activityType: UniversalActivityType
    public let stateText: String?
    public let priority: ActivityPriority
    public let timestamp: Date
    public let metadata: [String: String]
    public let confidence: ActivityConfidence
    public let source: String
    public let glyph: String?
    
    public init(
        applicationName: String,
        bundleIdentifier: String,
        activityType: UniversalActivityType = .appActive,
        stateText: String? = "Active",
        priority: ActivityPriority = .appActive,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        confidence: ActivityConfidence = .low,
        source: String = "UniversalDiscovery",
        glyph: String? = nil
    ) {
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.activityType = activityType
        self.stateText = stateText
        self.priority = priority
        self.timestamp = timestamp
        self.metadata = metadata
        self.confidence = confidence
        self.source = source
        self.glyph = glyph ?? UniversalAppActivity.resolveCategoryGlyph(applicationName: applicationName, bundleIdentifier: bundleIdentifier, activityType: activityType)
    }
    
    /// Formatted presentation title for the activity capsule.
    /// Follows guidelines:
    /// - Building: ⚒ Xcode • Building
    /// - Media: ▶ Chrome • Playing
    /// - Rendering: ◉ DaVinci • Rendering
    /// - Generic Active: ⌘ Terminal • Active or ◇ Figma • Active
    public var formattedTitle: String {
        let prefix = glyph ?? activityType.defaultGlyph
        if let state = stateText, !state.isEmpty {
            return "\(prefix) \(applicationName) • \(state)"
        } else {
            return "\(prefix) \(applicationName)"
        }
    }
    
    /// Resolves category-appropriate glyphs dynamically without hardcoded application lists.
    public static func resolveCategoryGlyph(applicationName: String, bundleIdentifier: String, activityType: UniversalActivityType) -> String {
        // If specific activity type is ongoing, use the activity glyph
        if activityType != .appActive && activityType != .appInactive {
            return activityType.defaultGlyph
        }
        
        let lowerName = applicationName.lowercased()
        let lowerBundle = bundleIdentifier.lowercased()
        
        // AHK Ecosystem
        if lowerBundle.contains("ahk.mini") {
            return "🎮"
        }
        if lowerBundle.contains("ahk.keychain") {
            return "🔑"
        }
        if lowerBundle.contains("ahk") {
            return "✨"
        }
        
        // Terminal / CLI / Shell
        if lowerName.contains("terminal") || lowerName.contains("iterm") || lowerName.contains("warp") || lowerName.contains("kitty") || lowerName.contains("alacritty") {
            return "⌘"
        }
        
        // Developer & IDEs
        if lowerName.contains("xcode") {
            return "⚒"
        }
        if lowerName.contains("antigravity") || lowerName.contains("cursor") || lowerName.contains("code") || lowerName.contains("intellij") || lowerName.contains("pycharm") || lowerName.contains("studio") {
            return "✦"
        }
        
        // Creative & Design
        if lowerName.contains("figma") {
            return "◇"
        }
        if lowerName.contains("photoshop") || lowerName.contains("illustrator") || lowerName.contains("blender") {
            return "✦"
        }
        if lowerName.contains("resolve") || lowerName.contains("final cut") || lowerName.contains("premiere") {
            return "◉"
        }
        
        // Communication
        if lowerName.contains("discord") {
            return "◉"
        }
        if lowerName.contains("slack") || lowerName.contains("messages") || lowerName.contains("whatsapp") || lowerName.contains("telegram") {
            return "💬"
        }
        if lowerName.contains("zoom") || lowerName.contains("teams") || lowerName.contains("meet") {
            return "📞"
        }
        
        // Gaming
        if lowerName.contains("steam") || lowerName.contains("minecraft") || lowerName.contains("game") {
            return "🎮"
        }
        
        // Web Browsers
        if lowerName.contains("safari") || lowerName.contains("chrome") || lowerName.contains("firefox") || lowerName.contains("arc") || lowerName.contains("brave") || lowerName.contains("edge") {
            return "🌐"
        }
        
        // Generic fallback for any Mac application
        return "●"
    }
}
