import AppKit
import Foundation
import QuartzCore

/// Delegate protocol for user interactions within the dynamic island.
@MainActor
public protocol IslandViewDelegate: AnyObject {
    func islandViewDidRequestToggleExpandCollapse(_ view: IslandView)
    func islandViewDidRequestDismissActivity(_ view: IslandView)
}

/// Dynamic Island presentation view adapting size, content, and styling to the active activity.
public final class IslandView: NSView, NowPlayingViewDelegate {
    
    public weak var delegate: IslandViewDelegate?
    
    // Container and Materials
    public let containerView = NSView()
    private let visualEffectView = NSVisualEffectView()
    private let darkTintView = NSView()
    
    // Activity Container
    private let contentContainerView = NSView()
    
    // Modular Subviews
    private let idleView = NSView()
    private let idleDot = NSView()
    
    public let volumeView = VolumeView()
    public let brightnessView = BrightnessView()
    public let batteryView = BatteryView()
    public let nowPlayingView = NowPlayingView()
    public let downloadView = DownloadView()
    public let fileTransferView = FileTransferView()
    public let notificationView = ActivityNotificationView()
    
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
        
        // Liquid glass backdrop
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        containerView.addSubview(visualEffectView)
        
        // Deep OLED dark tint
        darkTintView.wantsLayer = true
        darkTintView.layer?.backgroundColor = NSColor(white: 0.04, alpha: 0.94).cgColor
        darkTintView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(darkTintView)
        
        // Content container
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentContainerView)
        
        setupIdleView()
        setupModularViews()
        setupConstraints()
        
        // Initial idle presentation
        applyLayout(size: CGSize(width: 150, height: 26), cornerRadius: 13.0)
        showView(for: .idle)
    }
    
    private func setupIdleView() {
        idleView.translatesAutoresizingMaskIntoConstraints = false
        idleDot.translatesAutoresizingMaskIntoConstraints = false
        idleDot.wantsLayer = true
        idleDot.layer?.cornerRadius = 2.5
        idleDot.layer?.backgroundColor = NSColor(white: 0.75, alpha: 0.65).cgColor // Subtle idle accent
        
        idleView.addSubview(idleDot)
        NSLayoutConstraint.activate([
            idleDot.centerXAnchor.constraint(equalTo: idleView.centerXAnchor),
            idleDot.centerYAnchor.constraint(equalTo: idleView.centerYAnchor),
            idleDot.widthAnchor.constraint(equalToConstant: 16),
            idleDot.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    private func setupModularViews() {
        let modularViews: [NSView] = [
            idleView, volumeView, brightnessView, batteryView,
            nowPlayingView, downloadView, fileTransferView, notificationView
        ]
        
        for view in modularViews {
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
        
        nowPlayingView.delegate = self
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            darkTintView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            darkTintView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            darkTintView.topAnchor.constraint(equalTo: containerView.topAnchor),
            darkTintView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            contentContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    // MARK: - Activity Presentation
    
    public func present(activity: IslandActivity, isExpanded: Bool) {
        self.currentActivity = activity
        self.isExpanded = isExpanded
        
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
        case .battery:
            activeTargetView = batteryView
        case .nowPlaying:
            activeTargetView = nowPlayingView
        case .download:
            activeTargetView = downloadView
        case .fileTransfer:
            activeTargetView = fileTransferView
        case .notification:
            activeTargetView = notificationView
        }
        
        let allViews: [NSView] = [
            idleView, volumeView, brightnessView, batteryView,
            nowPlayingView, downloadView, fileTransferView, notificationView
        ]
        
        for view in allViews {
            view.isHidden = (view !== activeTargetView)
        }
    }
    
    private func updateActiveView(activity: IslandActivity, isExpanded: Bool) {
        switch activity {
        case .idle:
            break
        case .volume(let level, let isMuted):
            volumeView.update(level: level, isMuted: isMuted)
        case .brightness(let level):
            brightnessView.update(level: level)
        case .battery(let level, let isCharging, let isLow, let isCritical):
            batteryView.update(level: level, isCharging: isCharging, isLow: isLow, isCritical: isCritical)
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
        guard let layer = containerView.layer else { return }
        
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.cornerRadius = cornerRadius
        
        // Razor-sharp border highlight for visibility against all backgrounds
        layer.borderWidth = 1.0
        layer.borderColor = NSColor(white: 1.0, alpha: currentActivity == .idle ? 0.18 : 0.24).cgColor
        
        // Soft cinematic depth shadow
        wantsLayer = true
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = currentActivity == .idle ? 0.32 : 0.46
        self.layer?.shadowRadius = currentActivity == .idle ? 8.0 : 16.0
        self.layer?.shadowOffset = CGSize(width: 0, height: -3)
    }
    
    // MARK: - Hit Testing & Interaction
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let pointInContainer = containerView.convert(point, from: self)
        guard containerView.bounds.contains(pointInContainer) else {
            return nil
        }
        return super.hitTest(point)
    }
    
    public override func mouseUp(with event: NSEvent) {
        let pointInView = convert(event.locationInWindow, from: nil)
        let pointInContainer = containerView.convert(pointInView, from: self)
        guard containerView.bounds.contains(pointInContainer) else {
            super.mouseUp(with: event)
            return
        }
        
        // Pass click to buttons if clicked directly
        let hit = hitTest(pointInView)
        if hit is NSButton {
            super.mouseUp(with: event)
            return
        }
        
        // If an activity is active, tapping toggles its expanded view or dismisses
        delegate?.islandViewDidRequestToggleExpandCollapse(self)
    }
    
    // MARK: - NowPlayingViewDelegate
    
    public func nowPlayingViewDidRequestTogglePlayPause(_ view: NowPlayingView) {
        // Forwarded through coordinator
    }
    
    public func nowPlayingViewDidRequestNextTrack(_ view: NowPlayingView) {
        // Forwarded through coordinator
    }
    
    public func nowPlayingViewDidRequestPreviousTrack(_ view: NowPlayingView) {
        // Forwarded through coordinator
    }
}
