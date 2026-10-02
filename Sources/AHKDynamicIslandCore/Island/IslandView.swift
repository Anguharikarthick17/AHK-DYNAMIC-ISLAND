import AppKit
import Foundation
import QuartzCore

/// Delegate protocol for user interaction within the IslandView.
@MainActor
public protocol IslandViewDelegate: AnyObject {
    func islandViewDidRequestToggleExpandCollapse(_ view: IslandView)
    func islandViewDidRequestCollapse(_ view: IslandView)
}

/// The root view containing the visual Dynamic Island capsule and its expanded contents.
public final class IslandView: NSView {
    
    public weak var delegate: IslandViewDelegate?
    
    // MARK: - Subviews & Layers
    
    /// The interactive capsule container that scales and morphs between states.
    public let containerView = NSView()
    
    /// Visual effect backdrop (liquid glass).
    private let visualEffectView = NSVisualEffectView()
    
    /// Dark translucent OLED tint overlay.
    private let darkTintView = NSView()
    
    /// Expanded content container (hidden / alpha 0 when collapsed).
    public let expandedContentView = NSView()
    
    /// Top notch clearance view to prevent content from drawing under the physical camera.
    private let notchSpacerView = NSView()
    
    // Expanded sub-elements
    private let titleLabel = NSTextField(labelWithString: "AHK Dynamic Island")
    private let statusBadge = NSTextField(labelWithString: "● Active")
    private let displayInfoLabel = NSTextField(labelWithString: "Display: Built-in Retina")
    private let geometryLabel = NSTextField(labelWithString: "Notch Area Detected")
    private let collapseButton = NSButton()
    
    // MARK: - Layout State
    
    private var isExpanded: Bool = false
    private var notchClearanceHeight: CGFloat = 38.0
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Container view setup
        containerView.wantsLayer = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Liquid glass backdrop
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        containerView.addSubview(visualEffectView)
        
        // Dark translucent overlay
        darkTintView.wantsLayer = true
        darkTintView.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.92).cgColor
        darkTintView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(darkTintView)
        
        // Expanded content container
        expandedContentView.wantsLayer = true
        expandedContentView.alphaValue = 0.0
        expandedContentView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(expandedContentView)
        
        setupExpandedContentHierarchy()
        setupConstraints()
        applyContainerStyle(isExpanded: false)
    }
    
    private func setupExpandedContentHierarchy() {
        // Notch spacer at the top
        notchSpacerView.translatesAutoresizingMaskIntoConstraints = false
        expandedContentView.addSubview(notchSpacerView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.96, alpha: 1.0)
        expandedContentView.addSubview(titleLabel)
        
        // Status Badge
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        statusBadge.textColor = NSColor(red: 0.35, green: 0.85, blue: 0.55, alpha: 1.0) // Soft green
        expandedContentView.addSubview(statusBadge)
        
        // Display info
        displayInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        displayInfoLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        displayInfoLabel.textColor = NSColor(white: 0.72, alpha: 1.0)
        expandedContentView.addSubview(displayInfoLabel)
        
        // Geometry info
        geometryLabel.translatesAutoresizingMaskIntoConstraints = false
        geometryLabel.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        geometryLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        expandedContentView.addSubview(geometryLabel)
        
        // Collapse button
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        collapseButton.title = "Collapse"
        collapseButton.bezelStyle = .rounded
        collapseButton.controlSize = .small
        collapseButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        collapseButton.target = self
        collapseButton.action = #selector(handleCollapseButtonClicked)
        expandedContentView.addSubview(collapseButton)
        
        // Ensure subviews don't prevent capsule from shrinking when collapsed
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        displayInfoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        geometryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        expandedContentView.isHidden = true
    }
    
    private func setupConstraints() {
        // Container fills IslandView
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            darkTintView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            darkTintView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            darkTintView.topAnchor.constraint(equalTo: containerView.topAnchor),
            darkTintView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            expandedContentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            expandedContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            expandedContentView.topAnchor.constraint(equalTo: containerView.topAnchor),
            expandedContentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            // Notch clearance spacer
            notchSpacerView.topAnchor.constraint(equalTo: expandedContentView.topAnchor),
            notchSpacerView.leadingAnchor.constraint(equalTo: expandedContentView.leadingAnchor),
            notchSpacerView.trailingAnchor.constraint(equalTo: expandedContentView.trailingAnchor),
            notchSpacerView.heightAnchor.constraint(equalToConstant: notchClearanceHeight),
            
            // Title and status
            titleLabel.topAnchor.constraint(equalTo: notchSpacerView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: expandedContentView.leadingAnchor),
            
            statusBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusBadge.trailingAnchor.constraint(equalTo: expandedContentView.trailingAnchor),
            
            // Display info
            displayInfoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            displayInfoLabel.leadingAnchor.constraint(equalTo: expandedContentView.leadingAnchor),
            displayInfoLabel.trailingAnchor.constraint(equalTo: expandedContentView.trailingAnchor),
            
            // Geometry info
            geometryLabel.topAnchor.constraint(equalTo: displayInfoLabel.bottomAnchor, constant: 4),
            geometryLabel.leadingAnchor.constraint(equalTo: expandedContentView.leadingAnchor),
            
            // Collapse button
            collapseButton.trailingAnchor.constraint(equalTo: expandedContentView.trailingAnchor),
            collapseButton.bottomAnchor.constraint(equalTo: expandedContentView.bottomAnchor)
        ])
    }
    
    // MARK: - Styling & Layout Updates
    
    public func updateGeometry(info: ScreenGeometryInfo) {
        self.notchClearanceHeight = info.notchClearanceHeight
        
        let screenName = info.hasNotch ? "MacBook Retina (Hardware Notch)" : "Standard Screen (Fallback Anchor)"
        displayInfoLabel.stringValue = "Display: \(screenName)"
        
        let dims = "\(Int(info.screenFrame.width))×\(Int(info.screenFrame.height)) pt"
        let notchDesc = info.hasNotch ? "Notch: \(Int(info.notchRect.width))×\(Int(info.notchRect.height)) pt" : "No Notch"
        geometryLabel.stringValue = "\(dims) • \(notchDesc)"
        
        // Update notch spacer constraint if needed
        for constraint in expandedContentView.constraints {
            if constraint.firstItem === notchSpacerView && constraint.firstAttribute == .height {
                constraint.constant = info.notchClearanceHeight
            }
        }
    }
    
    public func applyContainerStyle(isExpanded: Bool) {
        self.isExpanded = isExpanded
        guard let layer = containerView.layer else { return }
        
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        
        // Corner radius:
        // Collapsed capsule corner radius matches half its height or ~18pt
        // Expanded rounded card has a sleek 24pt continuous corner radius
        layer.cornerRadius = isExpanded ? 24.0 : 18.0
        
        // Premium liquid glass border highlight
        layer.borderWidth = 0.5
        layer.borderColor = NSColor(white: 1.0, alpha: isExpanded ? 0.16 : 0.11).cgColor
        
        // Shadow configuration on self (or container)
        wantsLayer = true
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = isExpanded ? 0.42 : 0.30
        self.layer?.shadowRadius = isExpanded ? 18.0 : 10.0
        self.layer?.shadowOffset = CGSize(width: 0, height: -5)
    }
    
    public func setContentAlpha(_ alpha: CGFloat) {
        expandedContentView.alphaValue = alpha
        expandedContentView.isHidden = (alpha <= 0.001)
    }
    
    // MARK: - Hit Testing
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point to containerView coordinates
        let pointInContainer = containerView.convert(point, from: self)
        
        // If click is outside the visible island container, ignore it completely (pass through)
        guard containerView.bounds.contains(pointInContainer) else {
            return nil
        }
        
        // Pass through standard view hierarchy inside container
        return super.hitTest(point)
    }
    
    // MARK: - Mouse Interaction
    
    public override func mouseUp(with event: NSEvent) {
        let pointInView = convert(event.locationInWindow, from: nil)
        let pointInContainer = containerView.convert(pointInView, from: self)
        
        // Ensure click is inside container
        guard containerView.bounds.contains(pointInContainer) else {
            super.mouseUp(with: event)
            return
        }
        
        // If in expanded state and clicked on a button, let the button handle it
        if isExpanded {
            let hit = hitTest(pointInView)
            if hit === collapseButton {
                super.mouseUp(with: event)
                return
            }
        }
        
        // Otherwise, clicking the island toggles expand/collapse
        delegate?.islandViewDidRequestToggleExpandCollapse(self)
    }
    
    @objc private func handleCollapseButtonClicked() {
        delegate?.islandViewDidRequestCollapse(self)
    }
}
