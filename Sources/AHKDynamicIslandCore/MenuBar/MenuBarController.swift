import AppKit
import Foundation

/// Delegate protocol for actions initiated via the menu bar.
@MainActor
public protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidRequestToggleVisibility()
    func menuBarDidRequestToggleExpandCollapse()
    func menuBarDidRequestSettings()
    func menuBarDidRequestAbout()
    func menuBarDidRequestQuit()
}

/// Manages the macOS menu-bar status item and dropdown menu.
@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    
    public weak var delegate: MenuBarControllerDelegate?
    
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    
    // Dynamic menu items
    private let headerItem = NSMenuItem()
    private let onStateItem = NSMenuItem()
    private let visibilityItem = NSMenuItem()
    private let activityHeaderItem = NSMenuItem()
    private let activityStatusItem = NSMenuItem()
    private let settingsItem = NSMenuItem()
    private let aboutItem = NSMenuItem()
    private let quitItem = NSMenuItem()
    
    public override init() {
        super.init()
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = MenuBarIcon.createIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "AHK Dynamic Island"
        }
        
        setupMenu()
        item.menu = menu
        self.statusItem = item
    }
    
    private func setupMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        
        // Header
        headerItem.title = "AHK Dynamic Island"
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // On status
        onStateItem.title = "Dynamic Island: On ✓"
        onStateItem.isEnabled = false
        menu.addItem(onStateItem)
        
        // Visibility toggle
        visibilityItem.title = "Hide Island"
        visibilityItem.target = self
        visibilityItem.action = #selector(handleVisibilityClicked)
        visibilityItem.isEnabled = true
        menu.addItem(visibilityItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Current Activity section
        activityHeaderItem.title = "Current Activity"
        activityHeaderItem.isEnabled = false
        menu.addItem(activityHeaderItem)
        
        activityStatusItem.title = "Nothing active"
        activityStatusItem.target = self
        activityStatusItem.action = #selector(handleExpandCollapseClicked)
        activityStatusItem.isEnabled = true
        menu.addItem(activityStatusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Mini Timer Submenu
        let timerMenuItem = NSMenuItem(title: "Mini Timer", action: nil, keyEquivalent: "")
        let timerSubmenu = NSMenu(title: "Mini Timer")
        
        let timer5 = NSMenuItem(title: "Start 5 Minutes", action: #selector(handleStart5MinTimer), keyEquivalent: "")
        timer5.target = self
        timerSubmenu.addItem(timer5)
        
        let timer10 = NSMenuItem(title: "Start 10 Minutes", action: #selector(handleStart10MinTimer), keyEquivalent: "")
        timer10.target = self
        timerSubmenu.addItem(timer10)
        
        let timer25 = NSMenuItem(title: "Start 25 Minutes (Pomodoro)", action: #selector(handleStart25MinTimer), keyEquivalent: "")
        timer25.target = self
        timerSubmenu.addItem(timer25)
        
        timerSubmenu.addItem(NSMenuItem.separator())
        
        let cancelTimer = NSMenuItem(title: "Cancel Timer", action: #selector(handleCancelTimer), keyEquivalent: "")
        cancelTimer.target = self
        timerSubmenu.addItem(cancelTimer)
        
        timerMenuItem.submenu = timerSubmenu
        menu.addItem(timerMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        settingsItem.title = "Settings…"
        settingsItem.target = self
        settingsItem.action = #selector(handleSettingsClicked)
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)
        
        // About
        aboutItem.title = "About AHK Dynamic Island"
        aboutItem.target = self
        aboutItem.action = #selector(handleAboutClicked)
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        quitItem.title = "Quit"
        quitItem.target = self
        quitItem.action = #selector(handleQuitClicked)
        quitItem.isEnabled = true
        menu.addItem(quitItem)
    }
    
    // MARK: - State Synchronization
    
    public func updateVisibilityState(isVisible: Bool) {
        visibilityItem.title = isVisible ? "Hide Island" : "Show Island"
        onStateItem.title = isVisible ? "Dynamic Island: On ✓" : "Dynamic Island: Off"
    }
    
    public func updateActivity(_ activity: IslandActivity) {
        switch activity {
        case .idle:
            let name = DeviceIdentityManager.shared.fullIdlePresentation
            activityStatusItem.title = "Current Activity: \(name)"
        case .appActivity(let app):
            activityStatusItem.title = "\(app.applicationName): \(app.stateText ?? "Active")"
        case .volume(let level, let isMuted):
            activityStatusItem.title = isMuted ? "🔊 Volume Muted" : "🔊 Volume \(Int(level * 100))%"
        case .brightness(let level):
            activityStatusItem.title = "☀️ Brightness \(Int(level * 100))%"
        case .battery(let level, let isCharging, _, _):
            activityStatusItem.title = isCharging ? "🔋 Battery \(Int(level * 100))% ⚡" : "🔋 Battery \(Int(level * 100))%"
        case .charger(let isConnected, let percent):
            activityStatusItem.title = isConnected ? "⚡ Power Connected (\(percent)%)" : "🔋 Power Disconnected (\(percent)%)"
        case .audioDevice(let name, _, _):
            activityStatusItem.title = "🎧 Audio: \(name)"
        case .network(let statusText, _, _):
            activityStatusItem.title = "🌐 Network: \(statusText)"
        case .timer(let remaining, _, let isCompleted):
            activityStatusItem.title = isCompleted ? "⏱ Timer Complete" : "⏱ Timer: \(MiniTimerManager.format(remaining: remaining))"
        case .clipboard(let status):
            activityStatusItem.title = "📋 Clipboard: \(status)"
        case .nowPlaying(let state):
            activityStatusItem.title = "🎵 \(state.title)"
        case .download(let state):
            activityStatusItem.title = state.isCompleted ? "↓ Download Complete" : "↓ Downloading \(Int(state.progress * 100))%"
        case .fileTransfer(let state):
            activityStatusItem.title = state.isCompleted ? "✓ Transfer Complete" : "↑ Transfer: \(state.filename)"
        case .notification(let title, _, _):
            activityStatusItem.title = "Alert: \(title)"
        }
    }
    
    // MARK: - Mini Timer Actions
    
    @objc private func handleStart5MinTimer() {
        MiniTimerManager.shared.startTimer(duration: 300)
    }
    
    @objc private func handleStart10MinTimer() {
        MiniTimerManager.shared.startTimer(duration: 600)
    }
    
    @objc private func handleStart25MinTimer() {
        MiniTimerManager.shared.startTimer(duration: 1500)
    }
    
    @objc private func handleCancelTimer() {
        MiniTimerManager.shared.cancelTimer()
    }
    
    public func updateExpandCollapseState(isExpanded: Bool) {
        // Active item title remains descriptive
    }
    
    // MARK: - Actions
    
    @objc private func handleVisibilityClicked() {
        delegate?.menuBarDidRequestToggleVisibility()
    }
    
    @objc private func handleExpandCollapseClicked() {
        delegate?.menuBarDidRequestToggleExpandCollapse()
    }
    
    @objc private func handleSettingsClicked() {
        delegate?.menuBarDidRequestSettings()
    }
    
    @objc private func handleAboutClicked() {
        delegate?.menuBarDidRequestAbout()
    }
    
    @objc private func handleQuitClicked() {
        delegate?.menuBarDidRequestQuit()
    }
}
