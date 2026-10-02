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
            activityStatusItem.title = "Nothing active"
        case .volume(let level, let isMuted):
            activityStatusItem.title = isMuted ? "Volume: Muted" : "Volume: \(Int(level * 100))%"
        case .brightness(let level):
            activityStatusItem.title = "Brightness: \(Int(level * 100))%"
        case .battery(let level, let isCharging, _, _):
            activityStatusItem.title = isCharging ? "Battery: ⚡ \(Int(level * 100))%" : "Battery: 🔋 \(Int(level * 100))%"
        case .nowPlaying(let state):
            activityStatusItem.title = "Music: \(state.title)"
        case .download(let state):
            activityStatusItem.title = state.isCompleted ? "Download: Complete" : "Download: \(state.filename) (\(state.formattedProgress))"
        case .fileTransfer(let state):
            activityStatusItem.title = state.isCompleted ? "Transfer: Complete" : "Transfer: \(state.filename)"
        case .notification(let title, _, _):
            activityStatusItem.title = "Alert: \(title)"
        }
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
