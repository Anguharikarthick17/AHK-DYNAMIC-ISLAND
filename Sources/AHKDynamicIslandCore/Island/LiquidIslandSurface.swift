import AppKit
import Foundation
import QuartzCore

/// Multi-layered Liquid Glass physical surface for AHK Dynamic Island.
/// Combines native AppKit backdrop blur with 5 optical layers:
/// 1. Native translucent glass (NSVisualEffectView)
/// 2. Dark depth gradient (physical glass body)
/// 3. Soft internal specular highlight (top rim refraction)
/// 4. Specular light sweep (LiquidIslandHighlight)
/// 5. Subtle border highlight (LiquidIslandBorder)
/// 6. Soft ambient depth shadow
public final class LiquidIslandSurface: NSView {
    
    /// The container where subviews (labels, waveforms, controls) reside.
    public let contentView = NSView()
    
    /// Dynamic corner radius of the liquid glass capsule.
    public var cornerRadius: CGFloat = 13.0 {
        didSet {
            updateCornerRadius()
        }
    }
    
    /// Whether user interactions (clicks, hover) are permitted.
    public var isInteractive: Bool = false
    
    // Layer 1: Native Glass
    private let visualEffectView = NSVisualEffectView()
    
    // Layer 2: Dark Depth Gradient
    private let depthGradientLayer = CAGradientLayer()
    
    // Layer 3: Soft Internal Highlight (Top Rim Reflection)
    private let internalHighlightLayer = CAGradientLayer()
    
    // Layer 4: Specular Light Sweep
    public let highlightSweep = LiquidIslandHighlight()
    
    // Layer 5: Subtle Border & Border Highlight
    public let borderRim = LiquidIslandBorder()
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        
        // Layer 6: Soft Depth Shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.32
        layer?.shadowOffset = CGSize(width: 0, height: -3.5)
        layer?.shadowRadius = 12.0
        
        // Layer 1: Native Backdrop Glass
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        if #available(macOS 10.15, *) {
            visualEffectView.layer?.cornerCurve = .continuous
        }
        visualEffectView.layer?.masksToBounds = true
        addSubview(visualEffectView)
        
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Layer 2: Subtle Depth Gradient
        depthGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        depthGradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        depthGradientLayer.masksToBounds = true
        visualEffectView.layer?.addSublayer(depthGradientLayer)
        
        // Layer 3: Top Internal Highlight
        internalHighlightLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        internalHighlightLayer.endPoint = CGPoint(x: 0.5, y: 0.35)
        internalHighlightLayer.masksToBounds = true
        visualEffectView.layer?.addSublayer(internalHighlightLayer)
        
        // Layer 4: Specular Light Sweep
        visualEffectView.layer?.addSublayer(highlightSweep)
        
        // Content View sits above glass backgrounds, underneath border
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Layer 5: Perimeter Border
        layer?.addSublayer(borderRim)
        
        updateAppearanceStyle()
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        visualEffectView.layer?.cornerRadius = cornerRadius
        
        depthGradientLayer.frame = bounds
        depthGradientLayer.cornerRadius = cornerRadius
        
        internalHighlightLayer.frame = bounds
        internalHighlightLayer.cornerRadius = cornerRadius
        
        highlightSweep.frame = bounds
        highlightSweep.cornerRadius = cornerRadius
        
        borderRim.frame = bounds
        borderRim.cornerRadius = cornerRadius
        
        if #available(macOS 10.15, *) {
            depthGradientLayer.cornerCurve = .continuous
            internalHighlightLayer.cornerCurve = .continuous
            highlightSweep.cornerCurve = .continuous
            borderRim.cornerCurve = .continuous
        }
        
        CATransaction.commit()
    }
    
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearanceStyle()
    }
    
    private func updateCornerRadius() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visualEffectView.layer?.cornerRadius = cornerRadius
        depthGradientLayer.cornerRadius = cornerRadius
        internalHighlightLayer.cornerRadius = cornerRadius
        highlightSweep.cornerRadius = cornerRadius
        borderRim.cornerRadius = cornerRadius
        CATransaction.commit()
    }
    
    private func updateAppearanceStyle() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if isDark {
            visualEffectView.material = .hudWindow
            layer?.shadowOpacity = 0.35
            
            // Optical dark glass depth
            depthGradientLayer.colors = [
                NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 0.72).cgColor,
                NSColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 0.88).cgColor
            ]
            
            // Faint top specular reflection
            internalHighlightLayer.colors = [
                NSColor(white: 1.0, alpha: 0.12).cgColor,
                NSColor(white: 1.0, alpha: 0.0).cgColor
            ]
        } else {
            visualEffectView.material = .popover
            layer?.shadowOpacity = 0.16
            
            // Optical light glass depth
            depthGradientLayer.colors = [
                NSColor(white: 1.0, alpha: 0.75).cgColor,
                NSColor(white: 0.94, alpha: 0.85).cgColor
            ]
            
            internalHighlightLayer.colors = [
                NSColor(white: 1.0, alpha: 0.40).cgColor,
                NSColor(white: 1.0, alpha: 0.0).cgColor
            ]
        }
        
        highlightSweep.setAppearance(isDark: isDark)
        borderRim.setAppearance(isDark: isDark)
        CATransaction.commit()
    }
    
    // MARK: - Light Sweeps
    
    /// Triggers one complete activity transition shine:
    /// Specular light sweep across the surface + synchronized traveling border highlight.
    public func performActivityShine() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        highlightSweep.sweep(intensity: 1.0, duration: 1.30)
        borderRim.sweepBorder(duration: 1.25)
    }
    
    /// Triggers one soft, whisper-quiet idle specular shine (no border sweep).
    public func performIdleShine() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        highlightSweep.sweep(intensity: 0.55, duration: 1.65)
    }
    
    /// Halts all active shine effects immediately.
    public func stopAllShine() {
        highlightSweep.stopSweep()
        borderRim.stopBorderSweep()
    }
}
