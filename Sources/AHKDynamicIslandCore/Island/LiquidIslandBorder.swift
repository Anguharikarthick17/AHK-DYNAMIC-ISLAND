import AppKit
import Foundation
import QuartzCore

/// Animated perimeter border with traveling highlight sheen.
/// At rest, displays a faint glass bevel. During activity transitions,
/// a refined specular gleam glides along the capsule edge before fading smoothly.
public final class LiquidIslandBorder: CALayer {
    
    // Base quiet glass rim
    private let baseBorderLayer = CALayer()
    
    // Traveling border sheen
    private let sheenShapeLayer = CAShapeLayer()
    private var isDark: Bool = true
    
    public override init() {
        super.init()
        setupLayers()
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        masksToBounds = false
        needsDisplayOnBoundsChange = true
        
        // Base subtle glass edge
        baseBorderLayer.borderWidth = 0.65
        baseBorderLayer.masksToBounds = true
        addSublayer(baseBorderLayer)
        
        // Sheen stroke along capsule perimeter
        sheenShapeLayer.fillColor = nil
        sheenShapeLayer.lineWidth = 1.0
        sheenShapeLayer.lineCap = .round
        sheenShapeLayer.strokeStart = 0.0
        sheenShapeLayer.strokeEnd = 0.0
        sheenShapeLayer.opacity = 0.0
        addSublayer(sheenShapeLayer)
        
        updateColors()
    }
    
    public override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        baseBorderLayer.frame = bounds
        baseBorderLayer.cornerRadius = cornerRadius
        if #available(macOS 10.15, *) {
            baseBorderLayer.cornerCurve = .continuous
        }
        
        sheenShapeLayer.frame = bounds
        let path = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        sheenShapeLayer.path = path
        
        CATransaction.commit()
    }
    
    public func setAppearance(isDark: Bool) {
        self.isDark = isDark
        updateColors()
    }
    
    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isDark {
            baseBorderLayer.borderColor = NSColor(white: 1.0, alpha: 0.13).cgColor
            sheenShapeLayer.strokeColor = NSColor(white: 1.0, alpha: 0.55).cgColor
        } else {
            baseBorderLayer.borderColor = NSColor(white: 0.0, alpha: 0.09).cgColor
            sheenShapeLayer.strokeColor = NSColor(white: 1.0, alpha: 0.75).cgColor
        }
        CATransaction.commit()
    }
    
    /// Sweeps a gleaming highlight segment along the border path.
    public func sweepBorder(duration: CFTimeInterval = 1.2) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return
        }
        
        sheenShapeLayer.removeAnimation(forKey: "borderSheen")
        
        // Animate strokeStart and strokeEnd to travel clockwise along the capsule
        let startAnim = CABasicAnimation(keyPath: "strokeStart")
        startAnim.fromValue = 0.0
        startAnim.toValue = 0.65
        
        let endAnim = CABasicAnimation(keyPath: "strokeEnd")
        endAnim.fromValue = 0.20
        endAnim.toValue = 0.85
        
        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [0.0, 1.0, 0.9, 0.0]
        opacityAnim.keyTimes = [0.0, 0.25, 0.70, 1.0]
        
        let group = CAAnimationGroup()
        group.animations = [startAnim, endAnim, opacityAnim]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1.0, 0.4, 1.0)
        group.isRemovedOnCompletion = true
        group.fillMode = .forwards
        
        sheenShapeLayer.add(group, forKey: "borderSheen")
    }
    
    public func stopBorderSweep() {
        sheenShapeLayer.removeAnimation(forKey: "borderSheen")
        sheenShapeLayer.strokeStart = 0.0
        sheenShapeLayer.strokeEnd = 0.0
        sheenShapeLayer.opacity = 0.0
    }
}
