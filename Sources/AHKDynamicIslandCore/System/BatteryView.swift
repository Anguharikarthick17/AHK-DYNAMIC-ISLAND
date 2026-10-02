import AppKit
import Foundation

/// Visual presentation for battery status, charging indicator, and low/critical power alerts.
public final class BatteryView: NSView {
    
    private let iconView = NSImageView()
    private let percentageLabel = NSTextField(labelWithString: "100%")
    private let statusLabel = NSTextField(labelWithString: "")
    
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
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        percentageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        percentageLabel.textColor = .white
        addSubview(percentageLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        statusLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        statusLabel.lineBreakMode = .byTruncatingTail
        addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            percentageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            percentageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            statusLabel.leadingAnchor.constraint(equalTo: percentageLabel.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    public func update(level: Float, isCharging: Bool, isLow: Bool, isCritical: Bool) {
        let percent = Int(level * 100)
        percentageLabel.stringValue = "\(percent)%"
        
        if isCritical {
            iconView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Critical Battery")
            iconView.contentTintColor = NSColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
            statusLabel.stringValue = "Critical Battery — Plug in"
            statusLabel.textColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        } else if isCharging {
            iconView.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charging")
            iconView.contentTintColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
            statusLabel.stringValue = "Charging"
            statusLabel.textColor = NSColor(white: 0.8, alpha: 1.0)
        } else if isLow {
            iconView.image = NSImage(systemSymbolName: "battery.25", accessibilityDescription: "Low Battery")
            iconView.contentTintColor = NSColor(red: 1.0, green: 0.65, blue: 0.2, alpha: 1.0)
            statusLabel.stringValue = "Low Battery"
            statusLabel.textColor = NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
        } else {
            let symbolName: String
            if level > 0.75 { symbolName = "battery.100" }
            else if level > 0.50 { symbolName = "battery.75" }
            else if level > 0.25 { symbolName = "battery.50" }
            else { symbolName = "battery.25" }
            
            iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Battery")
            iconView.contentTintColor = .white
            statusLabel.stringValue = ""
        }
    }
}
