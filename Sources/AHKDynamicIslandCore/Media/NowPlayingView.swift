import AppKit
import Foundation

/// Delegate protocol for user media playback interactions.
@MainActor
public protocol NowPlayingViewDelegate: AnyObject {
    func nowPlayingViewDidRequestTogglePlayPause(_ view: NowPlayingView)
    func nowPlayingViewDidRequestNextTrack(_ view: NowPlayingView)
    func nowPlayingViewDidRequestPreviousTrack(_ view: NowPlayingView)
}

/// Visual presentation for Now Playing media in compact and expanded island states.
public final class NowPlayingView: NSView {
    
    public weak var delegate: NowPlayingViewDelegate?
    
    // UI Elements
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    private let progressBar = NSProgressIndicator()
    
    // Playback control buttons
    private let prevButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    
    private var isExpanded: Bool = false
    
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
        
        // Icon / Album Art
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6.0
        iconView.layer?.masksToBounds = true
        iconView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music")
        iconView.contentTintColor = NSColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1.0) // Soft rose accent
        addSubview(iconView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(titleLabel)
        
        // Artist
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(artistLabel)
        
        // Progress bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isIndeterminate = false
        progressBar.minValue = 0.0
        progressBar.maxValue = 1.0
        progressBar.doubleValue = 0.0
        progressBar.style = .bar
        addSubview(progressBar)
        
        // Playback buttons
        setupButton(prevButton, systemIcon: "backward.fill", action: #selector(handlePrev))
        setupButton(playPauseButton, systemIcon: "play.fill", action: #selector(handlePlayPause))
        setupButton(nextButton, systemIcon: "forward.fill", action: #selector(handleNext))
        
        setupConstraints()
    }
    
    private func setupButton(_ button: NSButton, systemIcon: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.image = NSImage(systemSymbolName: systemIcon, accessibilityDescription: nil)
        button.contentTintColor = .white
        button.target = self
        button.action = action
        addSubview(button)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Icon
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Artist (visible in expanded)
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -8),
            
            // Progress bar
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            // Controls
            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 22),
            nextButton.heightAnchor.constraint(equalToConstant: 22),
            
            playPauseButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -8),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 22),
            playPauseButton.heightAnchor.constraint(equalToConstant: 22),
            
            prevButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -8),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 22),
            prevButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
    
    public func update(state: NowPlayingState, isExpanded: Bool) {
        self.isExpanded = isExpanded
        
        titleLabel.stringValue = state.title
        artistLabel.stringValue = state.artist
        progressBar.doubleValue = state.playbackProgress
        
        let playIcon = state.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.image = NSImage(systemSymbolName: playIcon, accessibilityDescription: nil)
        
        // Visibility adjustments based on compact vs expanded
        artistLabel.isHidden = !isExpanded
        progressBar.isHidden = !isExpanded
        prevButton.isHidden = !isExpanded
        playPauseButton.isHidden = !isExpanded
        nextButton.isHidden = !isExpanded
        
        if isExpanded {
            titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        } else {
            titleLabel.font = NSFont.systemFont(ofSize: 11.0, weight: .medium)
        }
    }
    
    @objc private func handlePrev() {
        delegate?.nowPlayingViewDidRequestPreviousTrack(self)
    }
    
    @objc private func handlePlayPause() {
        delegate?.nowPlayingViewDidRequestTogglePlayPause(self)
    }
    
    @objc private func handleNext() {
        delegate?.nowPlayingViewDidRequestNextTrack(self)
    }
}
