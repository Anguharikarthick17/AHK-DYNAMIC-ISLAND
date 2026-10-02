import AppKit
import Foundation

/// Delegate protocol for actions initiated via the menu bar.
@MainActor
public protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidRequestToggleVisibility()
    func menuBarDidRequestToggleExpandCollapse()
    func menuBarDidRequestSettings()
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
    private let visibilityItem = NSMenuItem()
    private let expandCollapseItem = NSMenuItem()
    private let settingsItem = NSMenuItem()
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
        
        // Visibility toggle
        visibilityItem.title = "Hide Island"
        visibilityItem.target = self
        visibilityItem.action = #selector(handleVisibilityClicked)
        visibilityItem.isEnabled = true
        menu.addItem(visibilityItem)
        
        // Expand/Collapse test toggle
        expandCollapseItem.title = "Expand Island"
        expandCollapseItem.target = self
        expandCollapseItem.action = #selector(handleExpandCollapseClicked)
        expandCollapseItem.isEnabled = true
        menu.addItem(expandCollapseItem)
        
        // Settings (placeholder for V0.1)
        settingsItem.title = "Settings…"
        settingsItem.target = self
        settingsItem.action = #selector(handleSettingsClicked)
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)
        
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
    }
    
    public func updateExpandCollapseState(isExpanded: Bool) {
        expandCollapseItem.title = isExpanded ? "Collapse Island" : "Expand Island"
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
    
    @objc private func handleQuitClicked() {
        delegate?.menuBarDidRequestQuit()
    }
}
