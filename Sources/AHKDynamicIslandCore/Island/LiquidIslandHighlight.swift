import AppKit
import Foundation
import QuartzCore

/// Specular Light Sweep layer inspired by VengeanceUI's moving diagonal light.
/// Employs GPU-accelerated CoreAnimation gradient transitions with 0% CPU consumption at rest.
public final class LiquidIslandHighlight: CALayer {
    
    private let gradientLayer = CAGradientLayer()
    private var isDark: Bool = true
    
    // Rest state: gradient peak is far off to the left (negative coordinates)
    private let restingLocations: [NSNumber] = [-1.0, -0.8, -0.6, -0.4, -0.2]
    
    public override init() {
        super.init()
        setupLayer()
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        masksToBounds = true
        needsDisplayOnBoundsChange = true
        
        // Diagonal gradient orientation (top-left to bottom-right across the pill)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.85)
        gradientLayer.locations = restingLocations
        gradientLayer.masksToBounds = true
        
        addSublayer(gradientLayer)
        updateColors()
    }
    
    public override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = cornerRadius
        if #available(macOS 10.15, *) {
            gradientLayer.cornerCurve = .continuous
        }
        CATransaction.commit()
    }
    
    public func setAppearance(isDark: Bool) {
        self.isDark = isDark
        updateColors()
    }
    
    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let highlightAlpha: CGFloat = isDark ? 0.16 : 0.32
        let highlightColor = NSColor(white: 1.0, alpha: highlightAlpha).cgColor
        let clearColor = NSColor.clear.cgColor
        
        gradientLayer.colors = [
            clearColor,
            clearColor,
            highlightColor,
            clearColor,
            clearColor
        ]
        CATransaction.commit()
    }
    
    /// Performs one single, fluid diagonal specular light sweep across the glass surface.
    ///
    /// - Parameters:
    ///   - intensity: Multiplier for peak shine brightness (e.g. 1.0 for activity, 0.6 for subtle idle).
    ///   - duration: Travel time across the capsule (typically 1.2s – 1.6s).
    public func sweep(intensity: CGFloat = 1.0, duration: CFTimeInterval = 1.35) {
        // If reduced motion is requested, suppress the sweep entirely
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return
        }
        
        gradientLayer.removeAnimation(forKey: "specularSweep")
        
        let startLocations: [NSNumber] = [-0.65, -0.40, -0.15, 0.10, 0.35]
        let endLocations: [NSNumber]   = [ 0.65,  0.90,  1.15, 1.40, 1.65]
        
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = startLocations
        anim.toValue = endLocations
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = true
        
        // Modulate opacity during the sweep if intensity is custom
        if intensity < 0.99 {
            let opacityAnim = CABasicAnimation(keyPath: "opacity")
            opacityAnim.fromValue = Float(intensity)
            opacityAnim.toValue = Float(intensity)
            opacityAnim.duration = duration
            opacityAnim.isRemovedOnCompletion = true
            gradientLayer.add(opacityAnim, forKey: "sweepOpacity")
        }
        
        gradientLayer.add(anim, forKey: "specularSweep")
    }
    
    /// Stops any ongoing sweep immediately and rests in offscreen state.
    public func stopSweep() {
        gradientLayer.removeAnimation(forKey: "specularSweep")
        gradientLayer.removeAnimation(forKey: "sweepOpacity")
        gradientLayer.locations = restingLocations
    }
}
