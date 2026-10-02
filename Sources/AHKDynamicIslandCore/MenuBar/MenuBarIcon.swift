import AppKit
import Foundation

/// Generates a crisp, template-style 18×18 pt monochrome menu-bar icon.
public enum MenuBarIcon {
    
    /// Creates the standard 18×18 pt template icon representing the dynamic island.
    public static func createIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw Dynamic Island capsule
            let capsuleRect = NSRect(x: 1.5, y: 5.5, width: 15.0, height: 7.0)
            let path = NSBezierPath(roundedRect: capsuleRect, xRadius: 3.5, yRadius: 3.5)
            
            // Outer pill outline
            path.lineWidth = 1.3
            NSColor.black.setStroke()
            path.stroke()
            
            // Subtle camera lens dot on the left side of the pill
            let dotRect = NSRect(x: 3.8, y: 7.8, width: 2.4, height: 2.4)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            NSColor.black.setFill()
            dotPath.fill()
            
            // Subtle sensor dot on the right
            let sensorRect = NSRect(x: 11.8, y: 8.2, width: 1.6, height: 1.6)
            let sensorPath = NSBezierPath(ovalIn: sensorRect)
            NSColor.black.setFill()
            sensorPath.fill()
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
}
