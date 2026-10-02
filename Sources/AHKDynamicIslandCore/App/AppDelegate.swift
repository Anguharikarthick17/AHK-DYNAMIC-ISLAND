import AppKit
import Foundation

/// Main application delegate for AHK Dynamic Island.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    public private(set) var appController: ApplicationController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app operates strictly as an accessory (no Dock icon)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        
        // Initialize central coordinator
        let controller = ApplicationController()
        self.appController = controller
        
        // Launch Dynamic Island
        controller.start()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Stop display observers and cleanly dismiss windows
        appController?.islandWindowController.displayObserver.stopObserving()
        appController?.islandWindowController.hide()
    }
    
    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
