import AppKit
import AHKDynamicIslandCore

// Entry point for native macOS application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
