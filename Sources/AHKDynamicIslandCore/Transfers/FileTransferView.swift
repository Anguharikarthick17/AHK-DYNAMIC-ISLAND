import AppKit
import Foundation

/// Visual presentation for file transfer progress (sending / receiving) in the dynamic island.
public final class FileTransferView: NSView {
    
    private let iconView = NSImageView()
    private let directionLabel = NSTextField(labelWithString: "")
    private let filenameLabel = NSTextField(labelWithString: "")
    private let progressBar = NSProgressIndicator()
    private let rateLabel = NSTextField(labelWithString: "")
    
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
        
        directionLabel.translatesAutoresizingMaskIntoConstraints = false
        directionLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        directionLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        addSubview(directionLabel)
        
        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        filenameLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        filenameLabel.textColor = .white
        filenameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(filenameLabel)
        
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isIndeterminate = false
        progressBar.minValue = 0.0
        progressBar.maxValue = 1.0
        progressBar.doubleValue = 0.0
        progressBar.style = .bar
        addSubview(progressBar)
        
        rateLabel.translatesAutoresizingMaskIntoConstraints = false
        rateLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        rateLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        rateLabel.alignment = .right
        addSubview(rateLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            
            directionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            directionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            rateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rateLabel.centerYAnchor.constraint(equalTo: directionLabel.centerYAnchor),
            
            filenameLabel.leadingAnchor.constraint(equalTo: directionLabel.leadingAnchor),
            filenameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            filenameLabel.topAnchor.constraint(equalTo: directionLabel.bottomAnchor, constant: 2),
            
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            progressBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    public func update(state: FileTransferState) {
        filenameLabel.stringValue = state.filename
        progressBar.doubleValue = state.progress
        
        if state.isCompleted {
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Complete")
            iconView.contentTintColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
            directionLabel.stringValue = "Transfer Complete"
            directionLabel.textColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
            rateLabel.stringValue = "Done"
        } else {
            let isSending = (state.direction == .sending)
            let iconName = isSending ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
            iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Transfer")
            iconView.contentTintColor = NSColor(red: 0.55, green: 0.5, blue: 1.0, alpha: 1.0) // Soft lavender
            directionLabel.stringValue = isSending ? "Sending" : "Receiving"
            directionLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
            rateLabel.stringValue = "\(state.transferRate) • ETA \(state.eta)"
        }
    }
}
