import AppKit

/// Visual presentation for audio device connection changes (e.g. AirPods, Bluetooth headphones, speakers).
public final class AudioDeviceView: NSView {
    
    let iconView = NSImageView()
    let deviceLabel = NSTextField(labelWithString: "")
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
        iconView.contentTintColor = .white
        addSubview(iconView)
        
        deviceLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        deviceLabel.textColor = .white
        deviceLabel.lineBreakMode = .byTruncatingTail
        addSubview(deviceLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        statusLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        statusLabel.lineBreakMode = .byTruncatingTail
        addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            
            deviceLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            deviceLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            deviceLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            
            statusLabel.leadingAnchor.constraint(equalTo: deviceLabel.trailingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1)
        ])
    }
    
    public func update(name: String, isConnected: Bool, icon: String) {
        deviceLabel.stringValue = name
        statusLabel.stringValue = isConnected ? "Connected" : "Disconnected"
        statusLabel.textColor = isConnected ? NSColor(white: 0.75, alpha: 1.0) : NSColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Audio Device")
    }
}
