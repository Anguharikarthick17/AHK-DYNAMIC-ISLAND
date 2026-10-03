import AppKit
import Foundation

/// Visual presentation for download progress and completion in the dynamic island.
public final class DownloadView: NSView {
    
    let iconView = NSImageView()
    let headerLabel = NSTextField(labelWithString: "Downloading")
    let filenameLabel = NSTextField(labelWithString: "")
    let progressBar = NSProgressIndicator()
    let statsLabel = NSTextField(labelWithString: "")
    
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
        iconView.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Download")
        iconView.contentTintColor = NSColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1.0) // Soft azure
        addSubview(iconView)
        
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        headerLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        addSubview(headerLabel)
        
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
        
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        statsLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        statsLabel.alignment = .right
        addSubview(statsLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            
            headerLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            statsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statsLabel.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            
            filenameLabel.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            filenameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            filenameLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 2),
            
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            progressBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    public func update(state: DownloadState) {
        filenameLabel.stringValue = state.filename
        progressBar.doubleValue = state.progress
        
        if state.isCompleted {
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Complete")
            iconView.contentTintColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
            if let app = state.appName, !app.isEmpty {
                headerLabel.stringValue = "\(app) Download Complete"
            } else {
                headerLabel.stringValue = "Download Complete"
            }
            headerLabel.textColor = NSColor(red: 0.35, green: 0.85, blue: 0.45, alpha: 1.0)
            statsLabel.stringValue = "Done"
        } else {
            iconView.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Downloading")
            iconView.contentTintColor = NSColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1.0)
            headerLabel.stringValue = "Downloading"
            headerLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
            statsLabel.stringValue = "\(state.formattedProgress) • \(state.formattedSize)"
        }
    }
}
