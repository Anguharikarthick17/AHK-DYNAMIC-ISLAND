import AppKit
import Foundation
import QuartzCore

/// Native Liquid Glass container view.
/// Employs Apple's native NSGlassEffectView on supported macOS systems (with availability checks)
/// and seamlessly falls back to NSVisualEffectView with continuous curvature on older macOS releases.
public final class LiquidGlassContainerView: NSView {
    
    /// The hosted content view embedded inside the glass.
    public let contentView = NSView()
    
    /// Whether the glass responds to interactive gesture physics.
    public var isInteractive: Bool = false {
        didSet {
            updateInteractiveState()
        }
    }
    
    /// The dynamic corner radius of the liquid glass capsule.
    public var cornerRadius: CGFloat = 13.0 {
        didSet {
            updateCornerRadius()
        }
    }
    
    // Internal glass views
    private var nativeGlassView: NSView?
    private var fallbackVisualEffectView: NSVisualEffectView?
    
    // Specular border and ambient refraction layer
    private let specularBorderLayer = CALayer()
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGlassHierarchy()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassHierarchy()
    }
    
    private func setupGlassHierarchy() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        
        // Ambient glass shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        layer?.shadowRadius = 10.0
        
        // 1. Compile-time check for future macOS versions
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.cornerRadius = cornerRadius
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = false
            }
            glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.20)
            addSubview(glass)
            self.nativeGlassView = glass
            
            contentView.translatesAutoresizingMaskIntoConstraints = false
            glass.contentView = contentView
        } else if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            // 2. Runtime support for systems where NSGlassEffectView is present in AppKit
            let glass = glassClass.init(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.setValue(cornerRadius, forKey: "cornerRadius")
            glass.setValue(false, forKey: "effectIsInteractive")
            glass.setValue(NSColor.windowBackgroundColor.withAlphaComponent(0.20), forKey: "tintColor")
            addSubview(glass)
            self.nativeGlassView = glass
            
            contentView.translatesAutoresizingMaskIntoConstraints = false
            glass.setValue(contentView, forKey: "contentView")
        } else {
            // 3. High-fidelity fallback for older macOS using NSVisualEffectView
            let vfx = NSVisualEffectView(frame: bounds)
            vfx.autoresizingMask = [.width, .height]
            vfx.material = .hudWindow
            vfx.blendingMode = .behindWindow
            vfx.state = .active
            vfx.wantsLayer = true
            vfx.layer?.cornerRadius = cornerRadius
            vfx.layer?.cornerCurve = .continuous
            vfx.layer?.masksToBounds = true
            addSubview(vfx)
            self.fallbackVisualEffectView = vfx
            
            contentView.translatesAutoresizingMaskIntoConstraints = false
            vfx.addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: vfx.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: vfx.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: vfx.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: vfx.bottomAnchor)
            ])
        }
        
        // Subtle specular highlight rim
        specularBorderLayer.borderWidth = 0.65
        specularBorderLayer.masksToBounds = true
        layer?.addSublayer(specularBorderLayer)
        
        updateAppearanceStyle()
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        specularBorderLayer.frame = bounds
        specularBorderLayer.cornerRadius = cornerRadius
        
        if let glass = nativeGlassView {
            glass.setValue(cornerRadius, forKey: "cornerRadius")
        } else {
            fallbackVisualEffectView?.layer?.cornerRadius = cornerRadius
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
        specularBorderLayer.cornerRadius = cornerRadius
        if let glass = nativeGlassView {
            glass.setValue(cornerRadius, forKey: "cornerRadius")
        } else {
            fallbackVisualEffectView?.layer?.cornerRadius = cornerRadius
        }
        CATransaction.commit()
    }
    
    private func updateInteractiveState() {
        if let glass = nativeGlassView {
            glass.setValue(isInteractive, forKey: "effectIsInteractive")
        }
    }
    
    private func updateAppearanceStyle() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isDark {
            specularBorderLayer.borderColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            layer?.shadowOpacity = 0.35
            nativeGlassView?.setValue(NSColor.black.withAlphaComponent(0.25), forKey: "tintColor")
        } else {
            specularBorderLayer.borderColor = NSColor(white: 0.0, alpha: 0.12).cgColor
            layer?.shadowOpacity = 0.15
            nativeGlassView?.setValue(NSColor.white.withAlphaComponent(0.35), forKey: "tintColor")
        }
        CATransaction.commit()
    }
}
