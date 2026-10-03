import AppKit
import Foundation
import QuartzCore

/// Delegate protocol for user interactions within the dynamic island.
@MainActor
public protocol IslandViewDelegate: AnyObject {
    func islandViewDidRequestToggleExpandCollapse(_ view: IslandView)
    func islandViewDidRequestDismissActivity(_ view: IslandView)
    func islandViewDidDetectCursorApproach(_ view: IslandView)
    func islandViewDidDetectCursorExit(_ view: IslandView)
}

public extension IslandViewDelegate {
    func islandViewDidDetectCursorApproach(_ view: IslandView) {}
    func islandViewDidDetectCursorExit(_ view: IslandView) {}
}

/// Dynamic Island presentation view adapting size, content, and styling to the active activity.
/// Encased in native Liquid Glass with responsive refraction and continuous adaptive geometry.
public final class IslandView: NSView, NowPlayingViewDelegate {
    
    public weak var delegate: IslandViewDelegate?
    
    // Container and Native Liquid Glass
    public let containerView = NSView()
    public let glassContainer = LiquidGlassContainerView()
    
    // Activity Container
    private let contentContainerView = NSView()
    
    // Liquid Glass Motion & Shine Orchestrator
    public let liquidAnimator = LiquidIslandAnimator()
    
    // Modular Subviews
    public let idleView = NSView()
    public let signatureLabel = NSTextField(labelWithString: "✦")
    public let idleLabel = NSTextField(labelWithString: DeviceIdentityManager.shared.computerName)
    
    public let appActivityView = AppActivityView()
    public let volumeView = VolumeView()
    public let brightnessView = BrightnessView()
    public let batteryView = BatteryView()
    public let nowPlayingView = NowPlayingView()
    public let downloadView = DownloadView()
    public let fileTransferView = FileTransferView()
    public let notificationView = ActivityNotificationView()
    public let audioDeviceView = AudioDeviceView()
    public let networkView = NetworkStateView()
    public let timerView = MiniTimerView()
    public let clipboardView = ClipboardView()
    
    public private(set) var currentActivity: IslandActivity = .idle
    public private(set) var isExpanded: Bool = false
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupHierarchy()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHierarchy()
    }
    
    private func setupHierarchy() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Container setup
        containerView.wantsLayer = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Liquid Glass container fills the entire visible capsule
        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(glassContainer)
        
        // Content container inside liquid glass
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.contentView.addSubview(contentContainerView)
        
        setupIdleView()
        setupModularViews()
        setupConstraints()
        
        liquidAnimator.surface = glassContainer.surface
        liquidAnimator.updateActivityState(.idle)
        
        // Initial idle presentation
        let initialWidth = DeviceIdentityManager.shared.idleCapsuleWidth
        applyLayout(size: CGSize(width: initialWidth, height: 26), cornerRadius: 13.0)
        showView(for: .idle)
    }
    
    private func setupIdleView() {
        idleView.translatesAutoresizingMaskIntoConstraints = false
        
        signatureLabel.translatesAutoresizingMaskIntoConstraints = false
        signatureLabel.isEditable = false
        signatureLabel.isSelectable = false
        signatureLabel.isBezeled = false
        signatureLabel.drawsBackground = false
        signatureLabel.font = NSFont.systemFont(ofSize: 8.5, weight: .semibold)
        signatureLabel.alignment = .center
        signatureLabel.setContentHuggingPriority(.required, for: .horizontal)
        signatureLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        idleLabel.translatesAutoresizingMaskIntoConstraints = false
        idleLabel.isEditable = false
        idleLabel.isSelectable = false
        idleLabel.isBezeled = false
        idleLabel.drawsBackground = false
        idleLabel.alignment = .center
        idleLabel.maximumNumberOfLines = 1
        idleLabel.usesSingleLineMode = true
        idleLabel.lineBreakMode = .byTruncatingTail
        idleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let stack = NSStackView(views: [signatureLabel, idleLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4.5
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        idleView.addSubview(stack)
        
        updateIdleIdentity()
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: idleView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: idleView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: idleView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: idleView.trailingAnchor, constant: -8)
        ])
        
        updateIdleAppearance()
    }
    
    public func updateIdleIdentity(name: String? = nil) {
        let text = name ?? DeviceIdentityManager.shared.fullIdlePresentation
        let font = NSFont.systemFont(ofSize: 11.0, weight: .semibold)
        let attrString = NSMutableAttributedString(string: text)
        attrString.addAttributes([
            .font: font,
            .kern: 0.6
        ], range: NSRange(location: 0, length: text.utf16.count))
        idleLabel.attributedStringValue = attrString
    }
    
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateIdleAppearance()
    }
    
    private func updateIdleAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        idleLabel.textColor = isDark ? NSColor(white: 0.94, alpha: 0.90) : NSColor(white: 0.12, alpha: 0.88)
        signatureLabel.textColor = isDark ? NSColor(white: 0.90, alpha: 0.50) : NSColor(white: 0.20, alpha: 0.50)
    }
    
    private func setupModularViews() {
        nowPlayingView.delegate = self
        
        let allViews: [NSView] = [
            idleView, appActivityView, volumeView, brightnessView, batteryView,
            nowPlayingView, downloadView, fileTransferView, notificationView,
            audioDeviceView, networkView, timerView, clipboardView
        ]
        
        for view in allViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isHidden = true
            contentContainerView.addSubview(view)
            
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor)
            ])
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            glassContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            glassContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            contentContainerView.leadingAnchor.constraint(equalTo: glassContainer.contentView.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: glassContainer.contentView.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: glassContainer.contentView.topAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: glassContainer.contentView.bottomAnchor)
        ])
    }
    
    // MARK: - Presentation & State Updates
    
    public func present(activity: IslandActivity, isExpanded: Bool) {
        self.currentActivity = activity
        self.isExpanded = isExpanded
        
        // Update glass interactivity
        glassContainer.isInteractive = (activity.isInteractive || isExpanded)
        
        // Update liquid glass motion & shine system
        liquidAnimator.updateActivityState(activity)
        
        showView(for: activity)
        updateActiveView(activity: activity, isExpanded: isExpanded)
    }
    
    private func showView(for activity: IslandActivity) {
        let activeTargetView: NSView
        switch activity {
        case .idle:
            activeTargetView = idleView
        case .volume:
            activeTargetView = volumeView
        case .brightness:
            activeTargetView = brightnessView
        case .battery, .charger:
            activeTargetView = batteryView
        case .audioDevice:
            activeTargetView = audioDeviceView
        case .network:
            activeTargetView = networkView
        case .timer:
            activeTargetView = timerView
        case .clipboard:
            activeTargetView = clipboardView
        case .nowPlaying:
            activeTargetView = nowPlayingView
        case .download:
            activeTargetView = downloadView
        case .fileTransfer:
            activeTargetView = fileTransferView
        case .notification:
            activeTargetView = notificationView
        case .appActivity:
            activeTargetView = appActivityView
        }
        
        let allViews: [NSView] = [
            idleView, appActivityView, volumeView, brightnessView, batteryView,
            nowPlayingView, downloadView, fileTransferView, notificationView,
            audioDeviceView, networkView, timerView, clipboardView
        ]
        
        for view in allViews {
            view.isHidden = (view !== activeTargetView)
        }
    }
    
    private func updateActiveView(activity: IslandActivity, isExpanded: Bool) {
        switch activity {
        case .idle:
            updateIdleIdentity()
        case .appActivity(let activity):
            appActivityView.update(activity: activity, isExpanded: isExpanded)
        case .volume(let level, let isMuted):
            volumeView.update(level: level, isMuted: isMuted)
        case .brightness(let level):
            brightnessView.update(level: level)
        case .battery(let level, let isCharging, let isLow, let isCritical):
            batteryView.update(level: level, isCharging: isCharging, isLow: isLow, isCritical: isCritical)
        case .charger(let isConnected, let percent):
            batteryView.updateCharger(isConnected: isConnected, percent: percent)
        case .audioDevice(let name, let isConnected, let icon):
            audioDeviceView.update(name: name, isConnected: isConnected, icon: icon)
        case .network(let statusText, let icon, let isWarning):
            networkView.update(statusText: statusText, icon: icon, isWarning: isWarning)
        case .timer(let remaining, let total, let isCompleted):
            timerView.update(remainingSeconds: remaining, totalSeconds: total, isCompleted: isCompleted)
        case .clipboard(let statusText):
            clipboardView.update(statusText: statusText)
        case .nowPlaying(let state):
            nowPlayingView.update(state: state, isExpanded: isExpanded)
        case .download(let state):
            downloadView.update(state: state)
        case .fileTransfer(let state):
            fileTransferView.update(state: state)
        case .notification(let title, let subtitle, let iconName):
            notificationView.update(title: title, subtitle: subtitle, iconName: iconName)
        }
    }
    
    public func applyLayout(size: CGSize, cornerRadius: CGFloat) {
        glassContainer.cornerRadius = cornerRadius
        containerView.layer?.cornerRadius = cornerRadius
        containerView.layer?.cornerCurve = .continuous
    }
    
    // MARK: - User Interaction
    
    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // If clicking inside interactive controls (like music buttons), let subviews handle
        if isExpanded && currentActivity.isInteractive {
            if let hit = hitTest(location), hit !== self && hit !== containerView && hit !== glassContainer {
                super.mouseDown(with: event)
                return
            }
        }
        
        delegate?.islandViewDidRequestToggleExpandCollapse(self)
    }
    
    // MARK: - Cursor Tracking for Auto-Hide
    
    private var cursorTrackingArea: NSTrackingArea?
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = cursorTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.cursorTrackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        delegate?.islandViewDidDetectCursorApproach(self)
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        delegate?.islandViewDidDetectCursorExit(self)
    }
    
    // MARK: - NowPlayingViewDelegate
    
    public func nowPlayingViewDidRequestTogglePlayPause(_ view: NowPlayingView) {
        // Forwarded through manager
    }
    
    public func nowPlayingViewDidRequestNextTrack(_ view: NowPlayingView) {
        // Forwarded through manager
    }
    
    public func nowPlayingViewDidRequestPreviousTrack(_ view: NowPlayingView) {
        // Forwarded through manager
    }
}
