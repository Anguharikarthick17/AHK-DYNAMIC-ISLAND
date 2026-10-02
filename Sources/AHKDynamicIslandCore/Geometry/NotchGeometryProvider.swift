import AppKit
import Foundation

/// Geometry calculation results for a given display screen.
public struct ScreenGeometryInfo: Equatable, Sendable {
    /// The full frame of the screen in global coordinates.
    public let screenFrame: NSRect
    
    /// The visible frame (excluding dock and menu bar).
    public let visibleFrame: NSRect
    
    /// Whether a hardware camera notch is present.
    public let hasNotch: Bool
    
    /// Physical notch bounding box in global coordinates (or empty if no notch).
    public let notchRect: NSRect
    
    /// Bottom Y coordinate of the physical notch in global coordinates.
    public let notchBottomY: CGFloat
    
    /// Safe gap between the notch bottom and the island top.
    public let gap: CGFloat
    
    /// Safe area top inset (height of notch area).
    public let safeAreaTop: CGFloat
    
    /// Height of macOS menu bar.
    public let menuBarHeight: CGFloat
    
    /// The center anchor point at the top of the island.
    public let anchorPoint: NSPoint
    
    /// Collapsed island size.
    public let collapsedSize: CGSize
    
    /// Expanded island size.
    public let expandedSize: CGSize
    
    /// Collapsed island frame in global screen coordinates.
    public let collapsedFrame: NSRect
    
    /// Expanded island frame in global screen coordinates.
    public let expandedFrame: NSRect
    
    /// Top padding inside the expanded island.
    public let notchClearanceHeight: CGFloat
    
    public init(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        hasNotch: Bool,
        notchRect: NSRect,
        notchBottomY: CGFloat,
        gap: CGFloat,
        safeAreaTop: CGFloat,
        menuBarHeight: CGFloat,
        anchorPoint: NSPoint,
        collapsedSize: CGSize,
        expandedSize: CGSize,
        collapsedFrame: NSRect,
        expandedFrame: NSRect,
        notchClearanceHeight: CGFloat
    ) {
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        self.hasNotch = hasNotch
        self.notchRect = notchRect
        self.notchBottomY = notchBottomY
        self.gap = gap
        self.safeAreaTop = safeAreaTop
        self.menuBarHeight = menuBarHeight
        self.anchorPoint = anchorPoint
        self.collapsedSize = collapsedSize
        self.expandedSize = expandedSize
        self.collapsedFrame = collapsedFrame
        self.expandedFrame = expandedFrame
        self.notchClearanceHeight = notchClearanceHeight
    }
}

/// Provides screen and notch geometry detection with safe fallbacks for non-notch displays.
public final class NotchGeometryProvider: @unchecked Sendable {
    
    /// Default safe gap between the bottom of the physical notch and the top of the island.
    public static let defaultGap: CGFloat = 6.0
    
    public init() {}
    
    /// Determines the best screen to attach the Dynamic Island to.
    /// Prefers the screen with a physical notch, otherwise falls back to main screen or first available.
    public func targetScreen(preferred: NSScreen? = nil) -> NSScreen? {
        if let preferred = preferred {
            return preferred
        }
        
        let allScreens = NSScreen.screens
        guard !allScreens.isEmpty else { return nil }
        
        // Find screen with notch
        for screen in allScreens {
            if hasPhysicalNotch(screen: screen) {
                return screen
            }
        }
        
        // Fallback to main screen or first screen
        return NSScreen.main ?? allScreens.first
    }
    
    /// Detects if a screen has a physical camera notch using native macOS safe area APIs.
    public func hasPhysicalNotch(screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            if screen.safeAreaInsets.top > 0 {
                if let left = screen.auxiliaryTopLeftArea,
                   let right = screen.auxiliaryTopRightArea,
                   right.minX > left.maxX {
                    return true
                }
                return screen.safeAreaInsets.top > 24.0
            }
        }
        return false
    }
    
    /// Computes the complete geometry info for a given NSScreen.
    public func geometry(for screen: NSScreen, gap: CGFloat = defaultGap) -> ScreenGeometryInfo {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        var safeAreaTop: CGFloat = 0
        var auxLeft: NSRect? = nil
        var auxRight: NSRect? = nil
        
        if #available(macOS 12.0, *) {
            safeAreaTop = screen.safeAreaInsets.top
            auxLeft = screen.auxiliaryTopLeftArea
            auxRight = screen.auxiliaryTopRightArea
        }
        
        return Self.calculate(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryLeft: auxLeft,
            auxiliaryRight: auxRight,
            gap: gap
        )
    }
    
    /// Pure calculation function positioning the island entirely BELOW the physical notch.
    public static func calculate(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        safeAreaInsetsTop: CGFloat,
        auxiliaryLeft: NSRect?,
        auxiliaryRight: NSRect?,
        gap: CGFloat = defaultGap
    ) -> ScreenGeometryInfo {
        let menuBarHeight = max(24.0, screenFrame.maxY - visibleFrame.maxY)
        
        var hasNotch = false
        var notchRect = NSRect.zero
        let notchBottomY: CGFloat
        
        if safeAreaInsetsTop > 0,
           let left = auxiliaryLeft,
           let right = auxiliaryRight,
           right.minX > left.maxX {
            hasNotch = true
            let notchWidth = right.minX - left.maxX
            let notchHeight = safeAreaInsetsTop
            let notchX = left.maxX
            let notchY = screenFrame.maxY - notchHeight
            notchRect = NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
            notchBottomY = notchY
        } else if safeAreaInsetsTop > 24.0 {
            // Safe fallback if auxiliary areas missing on notch display
            hasNotch = true
            let estimatedWidth: CGFloat = 208.0
            let notchX = screenFrame.midX - (estimatedWidth / 2.0)
            let notchY = screenFrame.maxY - safeAreaInsetsTop
            notchRect = NSRect(x: notchX, y: notchY, width: estimatedWidth, height: safeAreaInsetsTop)
            notchBottomY = notchY
        } else {
            hasNotch = false
            notchBottomY = screenFrame.maxY
        }
        
        let anchorX = hasNotch ? notchRect.midX : screenFrame.midX
        
        // Critical: Island top must sit BELOW the physical notch / camera region.
        let rawTopY = hasNotch ? (notchBottomY - gap) : min(screenFrame.maxY - gap, visibleFrame.maxY - gap)
        let islandTopY = rawTopY.rounded(.down)
        
        // Collapsed state: Compact idle capsule (150x26 pt)
        let cWidth: CGFloat = 150.0
        let cHeight: CGFloat = 26.0
        let collapsedSize = CGSize(width: cWidth, height: cHeight)
        
        // Expanded state: Rounded activity card (340x90 pt)
        let eWidth: CGFloat = 340.0
        let eHeight: CGFloat = 90.0
        let expandedSize = CGSize(width: eWidth, height: eHeight)
        
        // Top edge remains pinned at islandTopY, expanding downward
        let collapsedFrame = NSRect(
            x: anchorX - (cWidth / 2.0),
            y: islandTopY - cHeight,
            width: cWidth,
            height: cHeight
        )
        
        let expandedFrame = NSRect(
            x: anchorX - (eWidth / 2.0),
            y: islandTopY - eHeight,
            width: eWidth,
            height: eHeight
        )
        
        let notchClearanceHeight: CGFloat = 8.0
        
        return ScreenGeometryInfo(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            hasNotch: hasNotch,
            notchRect: notchRect,
            notchBottomY: notchBottomY,
            gap: gap,
            safeAreaTop: safeAreaInsetsTop,
            menuBarHeight: menuBarHeight,
            anchorPoint: NSPoint(x: anchorX, y: islandTopY),
            collapsedSize: collapsedSize,
            expandedSize: expandedSize,
            collapsedFrame: collapsedFrame,
            expandedFrame: expandedFrame,
            notchClearanceHeight: notchClearanceHeight
        )
    }
}
