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
    
    /// Top margin inside the expanded island to clear camera/notch.
    public let notchClearanceHeight: CGFloat
    
    public init(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        hasNotch: Bool,
        notchRect: NSRect,
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
                // Even if auxiliary areas are unavailable, a safeAreaInsets.top > 24 indicates notch area
                return screen.safeAreaInsets.top > 24.0
            }
        }
        return false
    }
    
    /// Computes the complete geometry info for a given NSScreen.
    public func geometry(for screen: NSScreen) -> ScreenGeometryInfo {
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
            auxiliaryRight: auxRight
        )
    }
    
    /// Pure calculation function suitable for testing without hardware screens.
    public static func calculate(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        safeAreaInsetsTop: CGFloat,
        auxiliaryLeft: NSRect?,
        auxiliaryRight: NSRect?
    ) -> ScreenGeometryInfo {
        let menuBarHeight = max(24.0, screenFrame.maxY - visibleFrame.maxY)
        
        var hasNotch = false
        var notchRect = NSRect.zero
        
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
        } else if safeAreaInsetsTop > 24.0 {
            // Safe fallback if auxiliary areas missing on notch display
            hasNotch = true
            let estimatedWidth: CGFloat = 208.0
            let notchX = screenFrame.midX - (estimatedWidth / 2.0)
            let notchY = screenFrame.maxY - safeAreaInsetsTop
            notchRect = NSRect(x: notchX, y: notchY, width: estimatedWidth, height: safeAreaInsetsTop)
        }
        
        let anchorX = hasNotch ? notchRect.midX : screenFrame.midX
        
        let collapsedSize: CGSize
        let expandedSize: CGSize
        let collapsedFrame: NSRect
        let expandedFrame: NSRect
        let notchClearanceHeight: CGFloat
        let anchorY: CGFloat
        
        if hasNotch {
            // Anchor flush with the top bezel
            anchorY = screenFrame.maxY
            notchClearanceHeight = notchRect.height
            
            // Collapsed wraps Users snugly around notch with comfortable corner radii
            let cWidth = (max(notchRect.width + 16.0, 224.0)).rounded(.up)
            let cHeight = (notchRect.height + 4.0).rounded(.up)
            collapsedSize = CGSize(width: cWidth, height: cHeight)
            
            // Expanded width and height
            let eWidth = max(notchRect.width + 160.0, 380.0)
            let eHeight: CGFloat = 160.0
            expandedSize = CGSize(width: eWidth, height: eHeight)
            
            collapsedFrame = NSRect(
                x: anchorX - (cWidth / 2.0),
                y: anchorY - cHeight,
                width: cWidth,
                height: cHeight
            )
            
            expandedFrame = NSRect(
                x: anchorX - (eWidth / 2.0),
                y: anchorY - eHeight,
                width: eWidth,
                height: eHeight
            )
        } else {
            // Non-notch fallback:
            // Position just below the menu bar with a subtle 4pt gap,
            // or if menu bar is auto-hidden (visibleFrame.maxY == screenFrame.maxY),
            // position 6pt below the top edge.
            let topMargin: CGFloat = 4.0
            anchorY = min(screenFrame.maxY - 6.0, visibleFrame.maxY - topMargin)
            notchClearanceHeight = 8.0
            
            let cWidth: CGFloat = 180.0
            let cHeight: CGFloat = 34.0
            collapsedSize = CGSize(width: cWidth, height: cHeight)
            
            let eWidth: CGFloat = 360.0
            let eHeight: CGFloat = 140.0
            expandedSize = CGSize(width: eWidth, height: eHeight)
            
            collapsedFrame = NSRect(
                x: anchorX - (cWidth / 2.0),
                y: anchorY - cHeight,
                width: cWidth,
                height: cHeight
            )
            
            expandedFrame = NSRect(
                x: anchorX - (eWidth / 2.0),
                y: anchorY - eHeight,
                width: eWidth,
                height: eHeight
            )
        }
        
        return ScreenGeometryInfo(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            hasNotch: hasNotch,
            notchRect: notchRect,
            safeAreaTop: safeAreaInsetsTop,
            menuBarHeight: menuBarHeight,
            anchorPoint: NSPoint(x: anchorX, y: anchorY),
            collapsedSize: collapsedSize,
            expandedSize: expandedSize,
            collapsedFrame: collapsedFrame,
            expandedFrame: expandedFrame,
            notchClearanceHeight: notchClearanceHeight
        )
    }
}
