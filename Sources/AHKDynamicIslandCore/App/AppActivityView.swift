import AppKit
import Foundation

/// Compact view presenting universal application activities within the Liquid Glass capsule.
@MainActor
public final class AppActivityView: NSView {
    
    // UI Elements
    private let iconImageView = NSImageView()
    private let glyphLabel = NSTextField(labelWithString: "●")
    private let titleLabel = NSTextField(labelWithString: "Application")
    private let statusLabel = NSTextField(labelWithString: "• Active")
    private let statusDot = NSView()
    
    // Expanded details container
    private let expandedDetailsStack = NSStackView()
    private let bundleIdLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    
    public private(set) var currentActivity: UniversalAppActivity?
    public private(set) var isExpanded: Bool = false
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // App icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 4.0
        iconImageView.layer?.masksToBounds = true
        addSubview(iconImageView)
        
        // Glyph fallback
        glyphLabel.translatesAutoresizingMaskIntoConstraints = false
        glyphLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        glyphLabel.alignment = .center
        glyphLabel.textColor = .labelColor
        addSubview(glyphLabel)
        
        // App title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(titleLabel)
        
        // Status subtitle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(statusLabel)
        
        // Activity status dot
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 2.5
        statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        addSubview(statusDot)
        
        // Expanded details stack
        expandedDetailsStack.translatesAutoresizingMaskIntoConstraints = false
        expandedDetailsStack.orientation = .vertical
        expandedDetailsStack.alignment = .leading
        expandedDetailsStack.spacing = 2.0
        expandedDetailsStack.isHidden = true
        addSubview(expandedDetailsStack)
        
        bundleIdLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        bundleIdLabel.textColor = .tertiaryLabelColor
        bundleIdLabel.lineBreakMode = .byTruncatingMiddle
        expandedDetailsStack.addArrangedSubview(bundleIdLabel)
        
        sourceLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .medium)
        sourceLabel.textColor = .secondaryLabelColor
        expandedDetailsStack.addArrangedSubview(sourceLabel)
        
        NSLayoutConstraint.activate([
            // Icon / Glyph
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
            
            glyphLabel.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
            glyphLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Status
            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusDot.leadingAnchor, constant: -8),
            
            // Dot
            statusDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 5),
            statusDot.heightAnchor.constraint(equalToConstant: 5),
            
            // Expanded details
            expandedDetailsStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            expandedDetailsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            expandedDetailsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6)
        ])
    }
    
    /// Updates the view with the specified universal activity.
    public func update(activity: UniversalAppActivity, isExpanded: Bool = false) {
        self.currentActivity = activity
        self.isExpanded = isExpanded
        
        titleLabel.stringValue = activity.applicationName
        
        if let state = activity.stateText, !state.isEmpty {
            statusLabel.stringValue = "• \(state)"
            statusLabel.isHidden = false
        } else {
            statusLabel.stringValue = ""
            statusLabel.isHidden = true
        }
        
        // Configure icon or category glyph
        let appIcon = resolveAppIcon(bundleIdentifier: activity.bundleIdentifier)
        if let icon = appIcon {
            iconImageView.image = icon
            iconImageView.isHidden = false
            glyphLabel.isHidden = true
        } else {
            iconImageView.isHidden = true
            glyphLabel.stringValue = activity.glyph ?? activity.activityType.defaultGlyph
            glyphLabel.isHidden = false
        }
        
        // Status dot color based on activity type
        switch activity.activityType {
        case .appActive:
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        case .mediaPlaying:
            statusDot.layer?.backgroundColor = NSColor.systemPurple.cgColor
        case .building:
            statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        case .rendering, .processing, .exporting:
            statusDot.layer?.backgroundColor = NSColor.systemBlue.cgColor
        case .syncing:
            statusDot.layer?.backgroundColor = NSColor.systemTeal.cgColor
        case .completed:
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        case .error:
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        default:
            statusDot.layer?.backgroundColor = NSColor.systemGray.cgColor
        }
        
        // Expanded details
        expandedDetailsStack.isHidden = !isExpanded
        if isExpanded {
            bundleIdLabel.stringValue = activity.bundleIdentifier
            sourceLabel.stringValue = "\(activity.confidence.displayName) (\(activity.source))"
        }
    }
    
    private func resolveAppIcon(bundleIdentifier: String) -> NSImage? {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appUrl.path)
        }
        return nil
    }
}
