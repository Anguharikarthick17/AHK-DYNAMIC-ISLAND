import AppKit

/// Visual presentation for privacy-safe clipboard activity notifications.
/// Displays only status confirmations (e.g. "✓ Copied", "✓ Text Copied").
/// Never displays or handles clipboard contents.
public final class ClipboardView: NSView {
    
    let iconView = NSImageView()
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
        iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied")
        iconView.contentTintColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
        addSubview(iconView)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.lineBreakMode = .byTruncatingTail
        addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            statusLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    public func update(statusText: String) {
        statusLabel.stringValue = statusText
    }
}
