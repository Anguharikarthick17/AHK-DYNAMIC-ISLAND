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

/// Lifecycle and operational state of a universal application activity.
public enum UniversalActivityState: String, Equatable, Sendable, CaseIterable {
    case idle
    case active
    case working
    case processing
    case building
    case compiling
    case testing
    case rendering
    case exporting
    case uploading
    case downloading
    case installing
    case playing
    case paused
    case waiting
    case completed
    case failed
    case cancelled
    
    /// Whether this state represents a finished task.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
    
    /// Whether this state represents an ongoing, active background workload.
    public var isOngoing: Bool {
        switch self {
        case .active, .working, .processing, .building, .compiling, .testing,
             .rendering, .exporting, .uploading, .downloading, .installing, .playing, .waiting:
            return true
        default:
            return false
        }
    }
}

/// Confidence rating for detected application activity.
/// HIGH: macOS or application publicly and explicitly exposes exact telemetry.
/// MEDIUM: activity can reasonably be determined through legitimate public system signals.
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
    public var applicationIdentity: String { bundleIdentifier }
    public let applicationName: String
    public let bundleIdentifier: String
    public let activityType: UniversalActivityType
    public let activityTitle: String
    public let activitySubtitle: String?
    public let activityState: UniversalActivityState
    public let progress: Double?
    public let isIndeterminate: Bool
    public let priority: ActivityPriority
    public let confidence: ActivityConfidence
    public let source: String
    public let startedAt: Date
    public let updatedAt: Date
    public let estimatedCompletion: Date?
    public let icon: String?
    public let glyph: String?
    public let metadata: [String: String]
    
    // Backward compatibility property for V0.3.1/V0.4
    public var stateText: String? {
        if let subtitle = activitySubtitle, !subtitle.isEmpty {
            return subtitle
        }
        return activityState == .active ? "Active" : activityState.rawValue.capitalized
    }
    
    // Backward compatibility alias for timestamp
    public var timestamp: Date {
        return updatedAt
    }
    
    /// Modern rich initializer for V0.5 live activity intelligence.
    public init(
        applicationName: String,
        bundleIdentifier: String,
        activityType: UniversalActivityType = .appActive,
        activityTitle: String? = nil,
        activitySubtitle: String? = nil,
        activityState: UniversalActivityState = .active,
        progress: Double? = nil,
        isIndeterminate: Bool = false,
        priority: ActivityPriority = .appActive,
        confidence: ActivityConfidence = .low,
        source: String = "UniversalDiscovery",
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        estimatedCompletion: Date? = nil,
        glyph: String? = nil,
        icon: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.activityType = activityType
        self.activityTitle = activityTitle ?? applicationName
        self.activitySubtitle = activitySubtitle
        self.activityState = activityState
        self.progress = progress
        self.isIndeterminate = isIndeterminate
        self.priority = priority
        self.confidence = confidence
        self.source = source
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.estimatedCompletion = estimatedCompletion
        self.glyph = glyph ?? UniversalAppActivity.resolveCategoryGlyph(applicationName: applicationName, bundleIdentifier: bundleIdentifier, activityType: activityType)
        self.icon = icon
        self.metadata = metadata
    }
    
    /// Backward-compatible initializer matching exact V0.3.1 & V0.4 signature and argument ordering.
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
        self.activityTitle = applicationName
        self.activitySubtitle = stateText
        self.activityState = .active
        self.progress = nil
        self.isIndeterminate = false
        self.priority = priority
        self.confidence = confidence
        self.source = source
        self.startedAt = timestamp
        self.updatedAt = timestamp
        self.estimatedCompletion = nil
        self.glyph = glyph ?? UniversalAppActivity.resolveCategoryGlyph(applicationName: applicationName, bundleIdentifier: bundleIdentifier, activityType: activityType)
        self.icon = nil
        self.metadata = metadata
    }
    
    /// Whether this activity represents a long-running background task (e.g. building, rendering, exporting).
    public var isTask: Bool {
        switch activityState {
        case .working, .processing, .building, .compiling, .testing,
             .rendering, .exporting, .uploading, .downloading, .installing, .playing:
            return true
        default:
            return false
        }
    }
    
    /// Whether this activity represents an ongoing persistent task.
    public var isOngoing: Bool {
        if activityState.isTerminal {
            return false
        }
        if isTask {
            return true
        }
        return activityType.isOngoing && activityType != .appActive
    }
    
    /// Formatted presentation title for the activity capsule.
    /// Follows guidelines:
    /// - Building: ⚒ Xcode • Building MyApp
    /// - Media: ▶ Chrome • Playing
    /// - Rendering: ◉ DaVinci • Rendering
    /// - Generic Active: ⌘ Terminal • Active or ◇ Figma • Active
    public var formattedTitle: String {
        let prefix = glyph ?? activityType.defaultGlyph
        if let subtitle = activitySubtitle, !subtitle.isEmpty {
            return "\(prefix) \(applicationName) • \(subtitle)"
        } else if let state = stateText, !state.isEmpty {
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
