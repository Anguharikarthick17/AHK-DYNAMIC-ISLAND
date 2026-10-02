import AppKit
import Foundation

/// Minimal, high-visibility visual presentation for system volume events.
public final class VolumeView: NSView {
    
    private let iconView = NSImageView()
    private let levelBar = NSProgressIndicator()
    private let percentageLabel = NSTextField(labelWithString: "100%")
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        wantsLayer = true
        
        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .white
        addSubview(iconView)
        
        // Level Bar
        levelBar.translatesAutoresizingMaskIntoConstraints = false
        levelBar.isIndeterminate = false
        levelBar.minValue = 0.0
        levelBar.maxValue = 1.0
        levelBar.doubleValue = 0.5
        levelBar.style = .bar
        addSubview(levelBar)
        
        // Percentage label
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        percentageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        percentageLabel.textColor = .white
        percentageLabel.alignment = .right
        addSubview(percentageLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            
            percentageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            percentageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentageLabel.widthAnchor.constraint(equalToConstant: 36),
            
            levelBar.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            levelBar.trailingAnchor.constraint(equalTo: percentageLabel.leadingAnchor, constant: -8),
            levelBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            levelBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    public func update(level: Float, isMuted: Bool) {
        let percent = Int(level * 100)
        percentageLabel.stringValue = "\(percent)%"
        levelBar.doubleValue = Double(level)
        
        let iconName: String
        if isMuted || level <= 0.001 {
            iconName = "speaker.slash.fill"
            iconView.contentTintColor = NSColor(red: 0.95, green: 0.4, blue: 0.4, alpha: 1.0)
        } else if level < 0.33 {
            iconName = "speaker.wave.1.fill"
            iconView.contentTintColor = .white
        } else if level < 0.66 {
            iconName = "speaker.wave.2.fill"
            iconView.contentTintColor = .white
        } else {
            iconName = "speaker.wave.3.fill"
            iconView.contentTintColor = .white
        }
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Volume")
    }
}
