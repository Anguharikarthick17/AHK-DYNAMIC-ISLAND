import AppKit
import Foundation

/// Visual presentation for notification cards.
public final class ActivityNotificationView: NSView {
    
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    
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
        iconView.contentTintColor = NSColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
        addSubview(iconView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        subtitleLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3)
        ])
    }
    
    public func update(title: String, subtitle: String?, iconName: String?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = (subtitle == nil || subtitle?.isEmpty == true)
        
        let icon = iconName ?? "bell.fill"
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Notification")
    }
}
