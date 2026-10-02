import AppKit
import Foundation

/// Size tiers supported by the dynamic island layout system.
public enum IslandSizeTier: String, Equatable, Sendable {
    case idle
    case smallEvent
    case mediumEvent
    case largeEvent
    case maximum
    
    public var defaultDimensions: CGSize {
        switch self {
        case .idle:
            return CGSize(width: 150.0, height: 26.0)
        case .smallEvent:
            return CGSize(width: 220.0, height: 38.0)
        case .mediumEvent:
            return CGSize(width: 280.0, height: 60.0)
        case .largeEvent:
            return CGSize(width: 320.0, height: 90.0)
        case .maximum:
            return CGSize(width: 340.0, height: 110.0)
        }
    }
    
    public var cornerRadius: CGFloat {
        switch self {
        case .idle:
            return 13.0 // Half height of 26pt = smooth capsule
        case .smallEvent:
            return 19.0 // Half height of 38pt = smooth capsule
        case .mediumEvent:
            return 22.0
        case .largeEvent:
            return 26.0
        case .maximum:
            return 28.0
        }
    }
}

/// Layout specification containing target frame, dimensions, and styling metrics.
public struct IslandLayoutSpec: Equatable, Sendable {
    public let size: CGSize
    public let frame: NSRect
    public let cornerRadius: CGFloat
    public let tier: IslandSizeTier
    public let contentInsets: NSEdgeInsets
    
    public init(
        size: CGSize,
        frame: NSRect,
        cornerRadius: CGFloat,
        tier: IslandSizeTier,
        contentInsets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    ) {
        self.size = size
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.tier = tier
        self.contentInsets = contentInsets
    }
    
    public static func == (lhs: IslandLayoutSpec, rhs: IslandLayoutSpec) -> Bool {
        return lhs.size == rhs.size &&
            lhs.frame == rhs.frame &&
            lhs.cornerRadius == rhs.cornerRadius &&
            lhs.tier == rhs.tier &&
            lhs.contentInsets.top == rhs.contentInsets.top &&
            lhs.contentInsets.left == rhs.contentInsets.left &&
            lhs.contentInsets.bottom == rhs.contentInsets.bottom &&
            lhs.contentInsets.right == rhs.contentInsets.right
    }
}

/// Dynamic size engine determining dimensions and notch-relative positioning for activities.
public final class IslandLayoutEngine: @unchecked Sendable {
    
    public static let shared = IslandLayoutEngine()
    
    public init() {}
    
    /// Computes the exact layout spec given the current activity, expansion state, and screen geometry.
    public func layoutSpec(
        for activity: IslandActivity,
        isExpanded: Bool,
        screenGeometry: ScreenGeometryInfo
    ) -> IslandLayoutSpec {
        let tier = determineTier(for: activity, isExpanded: isExpanded)
        let rawSize = calculateSize(for: activity, tier: tier, isExpanded: isExpanded)
        
        // Clamp within allowed bounds (150x26 min, 340x120 max)
        let clampedWidth = min(max(rawSize.width, 140.0), 340.0)
        let clampedHeight = min(max(rawSize.height, 24.0), 120.0)
        let size = CGSize(width: clampedWidth.rounded(), height: clampedHeight.rounded())
        
        let cornerRadius = calculateCornerRadius(for: size, tier: tier)
        
        // Top edge remains strictly pinned below notch anchor, growing downward
        let anchorX = screenGeometry.anchorPoint.x
        let topAnchorY = screenGeometry.anchorPoint.y
        
        let frame = NSRect(
            x: (anchorX - (size.width / 2.0)).rounded(),
            y: (topAnchorY - size.height).rounded(),
            width: size.width,
            height: size.height
        )
        
        let insets = calculateInsets(for: tier)
        return IslandLayoutSpec(size: size, frame: frame, cornerRadius: cornerRadius, tier: tier, contentInsets: insets)
    }
    
    private func determineTier(for activity: IslandActivity, isExpanded: Bool) -> IslandSizeTier {
        switch activity {
        case .idle:
            return isExpanded ? .largeEvent : .idle
            
        case .volume, .brightness:
            return isExpanded ? .mediumEvent : .smallEvent
            
        case .battery(_, _, _, let isCritical):
            if isCritical {
                return .mediumEvent
            }
            return isExpanded ? .mediumEvent : .smallEvent
            
        case .nowPlaying:
            return isExpanded ? .largeEvent : .smallEvent
            
        case .download:
            return isExpanded ? .largeEvent : .mediumEvent
            
        case .fileTransfer:
            return isExpanded ? .largeEvent : .mediumEvent
            
        case .notification:
            return isExpanded ? .largeEvent : .mediumEvent
            
        case .appActivity(let activity):
            if isExpanded {
                return .largeEvent
            }
            return activity.activityType.isOngoing ? .mediumEvent : .smallEvent
        }
    }
    
    private func calculateSize(for activity: IslandActivity, tier: IslandSizeTier, isExpanded: Bool) -> CGSize {
        switch activity {
        case .idle:
            return isExpanded ? CGSize(width: 340.0, height: 90.0) : IslandSizeTier.idle.defaultDimensions
            
        case .volume:
            return isExpanded ? CGSize(width: 250.0, height: 48.0) : CGSize(width: 210.0, height: 38.0)
            
        case .brightness:
            return isExpanded ? CGSize(width: 250.0, height: 48.0) : CGSize(width: 210.0, height: 38.0)
            
        case .battery(_, _, _, let isCritical):
            if isCritical {
                return CGSize(width: 260.0, height: 56.0)
            }
            return isExpanded ? CGSize(width: 240.0, height: 48.0) : CGSize(width: 190.0, height: 34.0)
            
        case .nowPlaying:
            return isExpanded ? CGSize(width: 320.0, height: 90.0) : CGSize(width: 220.0, height: 38.0)
            
        case .download:
            return isExpanded ? CGSize(width: 320.0, height: 92.0) : CGSize(width: 270.0, height: 58.0)
            
        case .fileTransfer:
            return isExpanded ? CGSize(width: 320.0, height: 92.0) : CGSize(width: 270.0, height: 58.0)
            
        case .notification:
            return isExpanded ? CGSize(width: 330.0, height: 94.0) : CGSize(width: 280.0, height: 60.0)
            
        case .appActivity(let activity):
            if isExpanded {
                return CGSize(width: 310.0, height: 86.0)
            }
            if activity.activityType.isOngoing {
                return CGSize(width: 235.0, height: 40.0)
            }
            return CGSize(width: 210.0, height: 38.0)
        }
    }
    
    private func calculateCornerRadius(for size: CGSize, tier: IslandSizeTier) -> CGFloat {
        if size.height <= 40.0 {
            return (size.height / 2.0).rounded()
        }
        return tier.cornerRadius
    }
    
    private func calculateInsets(for tier: IslandSizeTier) -> NSEdgeInsets {
        switch tier {
        case .idle:
            return NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        case .smallEvent:
            return NSEdgeInsets(top: 2, left: 12, bottom: 2, right: 12)
        case .mediumEvent:
            return NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        case .largeEvent, .maximum:
            return NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        }
    }
}
