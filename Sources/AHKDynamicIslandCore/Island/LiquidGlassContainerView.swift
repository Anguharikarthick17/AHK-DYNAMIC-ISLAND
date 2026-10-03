import AppKit
import Foundation
import QuartzCore

/// Native Liquid Glass container view housing the AHK Liquid Glass Motion System.
/// Coordinates the 6 optical layers of LiquidIslandSurface:
/// 1. Native translucent glass (NSVisualEffectView)
/// 2. Dark depth gradient
/// 3. Soft internal specular curve
/// 4. Specular light sweep (LiquidIslandHighlight)
/// 5. Subtle border highlight (LiquidIslandBorder)
/// 6. Soft ambient depth shadow
public final class LiquidGlassContainerView: NSView {
    
    /// The physical multi-layer liquid glass surface.
    public let surface = LiquidIslandSurface()
    
    /// The hosted content view embedded inside the glass.
    public var contentView: NSView {
        return surface.contentView
    }
    
    /// Whether the glass responds to interactive gesture physics.
    public var isInteractive: Bool {
        get { surface.isInteractive }
        set { surface.isInteractive = newValue }
    }
    
    /// The dynamic corner radius of the liquid glass capsule.
    public var cornerRadius: CGFloat {
        get { surface.cornerRadius }
        set { surface.cornerRadius = newValue }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContainer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContainer()
    }
    
    private func setupContainer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    public func performActivityShine() {
        surface.performActivityShine()
    }
    
    public func performIdleShine() {
        surface.performIdleShine()
    }
    
    public func stopAllShine() {
        surface.stopAllShine()
    }
}
