import AppKit

/// Visual presentation for dynamic island timer countdowns and completion notifications.
public final class MiniTimerView: NSView {
    
    let iconView = NSImageView()
    let timeLabel = NSTextField(labelWithString: "")
    let statusLabel = NSTextField(labelWithString: "")
    
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
        iconView.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer")
        iconView.contentTintColor = NSColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1.0)
        addSubview(iconView)
        
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .semibold)
        timeLabel.textColor = .white
        addSubview(timeLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11.0, weight: .medium)
        statusLabel.textColor = NSColor(white: 0.75, alpha: 1.0)
        addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            timeLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            statusLabel.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    public func update(remainingSeconds: TimeInterval, totalSeconds: TimeInterval, isCompleted: Bool) {
        if isCompleted {
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Timer Complete")
            iconView.contentTintColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
            timeLabel.stringValue = "Timer Complete"
            timeLabel.font = NSFont.systemFont(ofSize: 12.0, weight: .semibold)
            statusLabel.stringValue = ""
        } else {
            iconView.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer")
            iconView.contentTintColor = NSColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1.0)
            timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .semibold)
            timeLabel.stringValue = MiniTimerManager.format(remaining: remainingSeconds)
            statusLabel.stringValue = ""
        }
    }
}
