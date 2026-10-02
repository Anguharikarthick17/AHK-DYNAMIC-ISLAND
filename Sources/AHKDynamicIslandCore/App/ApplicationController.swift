import AppKit
import Foundation

/// Central coordinator for the AHK Dynamic Island application.
@MainActor
public final class ApplicationController: NSObject, MenuBarControllerDelegate {
    
    public let islandWindowController: IslandWindowController
    public let menuBarController: MenuBarController
    public let performanceMonitor: PerformanceMonitor
    
    public init(
        islandWindowController: IslandWindowController = IslandWindowController(),
        menuBarController: MenuBarController = MenuBarController(),
        performanceMonitor: PerformanceMonitor = PerformanceMonitor.shared
    ) {
        self.islandWindowController = islandWindowController
        self.menuBarController = menuBarController
        self.performanceMonitor = performanceMonitor
        
        super.init()
        
        setupCoordination()
    }
    
    private func setupCoordination() {
        menuBarController.delegate = self
        
        // Sync state changes to menu bar
        islandWindowController.onStateChanged = { [weak self] state in
            self?.menuBarController.updateExpandCollapseState(isExpanded: state.isExpandedOrExpanding)
        }
        
        islandWindowController.onVisibilityChanged = { [weak self] isVisible in
            self?.menuBarController.updateVisibilityState(isVisible: isVisible)
        }
    }
    
    /// Starts the application, showing the island in its initial collapsed state.
    public func start() {
        islandWindowController.show()
    }
    
    // MARK: - MenuBarControllerDelegate
    
    public func menuBarDidRequestToggleVisibility() {
        islandWindowController.toggleVisibility()
    }
    
    public func menuBarDidRequestToggleExpandCollapse() {
        islandWindowController.toggleExpandCollapse()
    }
    
    public func menuBarDidRequestSettings() {
        let alert = NSAlert()
        alert.messageText = "AHK Dynamic Island — Settings"
        alert.informativeText = "Version: 0.1 Foundation\n\nActive Screen: \(islandWindowController.currentGeometry.hasNotch ? "MacBook Retina (Hardware Notch)" : "Standard Display (Fallback Anchor)")\nIsland Geometry: \(Int(islandWindowController.currentGeometry.collapsedSize.width))×\(Int(islandWindowController.currentGeometry.collapsedSize.height)) pt (Collapsed)\n\nModular preferences will be configurable in V0.2."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }
    
    public func menuBarDidRequestQuit() {
        NSApplication.shared.terminate(nil)
    }
}
