import AppKit
import Foundation

/// Central coordinator for the AHK Dynamic Island application in V0.2.
@MainActor
public final class ApplicationController: NSObject, MenuBarControllerDelegate {
    
    public let islandWindowController: IslandWindowController
    public let menuBarController: MenuBarController
    public let performanceMonitor: PerformanceMonitor
    
    // V0.2 Dynamic Activity Engines
    public let eventCoordinator: IslandEventCoordinator
    public let volumeMonitor: VolumeMonitor
    public let brightnessMonitor: BrightnessMonitor
    public let batteryMonitor: BatteryMonitor
    public let nowPlayingManager: NowPlayingManager
    public let downloadManager: DownloadManager
    public let fileTransferManager: FileTransferManager
    public let notificationCoordinator: ActivityNotificationCoordinator
    public let eventBus: AHKEventBus
    
    public init(
        islandWindowController: IslandWindowController = IslandWindowController(),
        menuBarController: MenuBarController = MenuBarController(),
        performanceMonitor: PerformanceMonitor = PerformanceMonitor.shared,
        eventCoordinator: IslandEventCoordinator = IslandEventCoordinator()
    ) {
        self.islandWindowController = islandWindowController
        self.menuBarController = menuBarController
        self.performanceMonitor = performanceMonitor
        self.eventCoordinator = eventCoordinator
        
        self.volumeMonitor = VolumeMonitor()
        self.brightnessMonitor = BrightnessMonitor()
        self.batteryMonitor = BatteryMonitor()
        self.nowPlayingManager = NowPlayingManager()
        self.downloadManager = DownloadManager()
        self.fileTransferManager = FileTransferManager()
        self.notificationCoordinator = ActivityNotificationCoordinator()
        self.eventBus = AHKEventBus.shared
        
        super.init()
        
        setupCoordination()
        wireActivityMonitors()
    }
    
    private func setupCoordination() {
        menuBarController.delegate = self
        
        // Synchronize activity and layout state to menu bar
        eventCoordinator.onActivityChanged = { [weak self] activity in
            guard let self = self else { return }
            self.menuBarController.updateActivity(activity)
            self.islandWindowController.presentActivity(activity, isExpanded: false, animated: true)
        }
        
        islandWindowController.onStateChanged = { [weak self] state in
            self?.menuBarController.updateExpandCollapseState(isExpanded: state.isExpandedOrExpanding)
        }
        
        islandWindowController.onVisibilityChanged = { [weak self] isVisible in
            self?.menuBarController.updateVisibilityState(isVisible: isVisible)
        }
        
        setupDistributedCommands()
    }
    
    private func wireActivityMonitors() {
        // Volume
        volumeMonitor.onVolumeChanged = { [weak self] level, isMuted in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.volume(level: level, isMuted: isMuted))
            }
        }
        
        // Brightness
        brightnessMonitor.onBrightnessChanged = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.brightness(level: level))
            }
        }
        
        // Battery
        batteryMonitor.onBatteryStatusChanged = { [weak self] info in
            Task { @MainActor [weak self] in
                // Post battery activity when charging, low, or critical
                if info.isCharging || info.isLow || info.isCritical {
                    self?.eventCoordinator.postActivity(.battery(
                        level: info.level,
                        isCharging: info.isCharging,
                        isLow: info.isLow,
                        isCritical: info.isCritical
                    ))
                }
            }
        }
        
        // Media / Now Playing
        nowPlayingManager.onPlaybackStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                if state.isPlaying {
                    self?.eventCoordinator.postActivity(.nowPlaying(state: state))
                } else if self?.eventCoordinator.activeActivity == .nowPlaying(state: state) {
                    self?.eventCoordinator.clearCurrentActivity()
                }
            }
        }
        
        // Downloads
        downloadManager.onDownloadProgress = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.download(state: state))
            }
        }
        
        // File Transfers
        fileTransferManager.onTransferProgress = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.fileTransfer(state: state))
            }
        }
        
        // Notifications
        notificationCoordinator.onNotificationPosted = { [weak self] title, subtitle, icon in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.notification(title: title, subtitle: subtitle, iconName: icon))
            }
        }
        
        // Ecosystem bus forwarding
        eventBus.subscribe { [weak self] event in
            Task { @MainActor [weak self] in
                let title = event.payload["title"] ?? event.name
                let subtitle = event.payload["subtitle"]
                self?.eventCoordinator.postActivity(.notification(title: title, subtitle: subtitle, iconName: "sparkles"))
            }
        }
    }
    
    private func setupDistributedCommands() {
        let center = DistributedNotificationCenter.default()
        
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.toggleExpand"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.islandWindowController.toggleExpandCollapse() }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.expand"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.islandWindowController.expand() }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.collapse"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.islandWindowController.collapse() }
        }
        
        // Simulation hooks for verification
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.volume"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.volumeMonitor.simulateVolumeChange(level: 0.72, isMuted: false) }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.brightness"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.brightnessMonitor.setBrightness(level: 0.68) }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.music"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.nowPlayingManager.simulateTrack(title: "Midnight City", artist: "M83", isPlaying: true)
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.battery"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.batteryMonitor.simulateBattery(level: 0.84, isCharging: true, isPluggedIn: true) }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.download"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                let id = self?.downloadManager.startDownload(filename: "Xcode_16.2.xip", totalBytes: 145 * 1024 * 1024)
                if let id = id {
                    self?.downloadManager.updateProgress(id: id, bytesReceived: 120 * 1024 * 1024)
                }
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.transfer"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                let id = self?.fileTransferManager.startTransfer(filename: "Presentation.key", direction: .sending, totalBytes: 50 * 1024 * 1024)
                if let id = id {
                    self?.fileTransferManager.updateProgress(id: id, bytesTransferred: 35 * 1024 * 1024)
                }
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.simulate.idle"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.eventCoordinator.clearCurrentActivity() }
        }
    }
    
    /// Starts the application and event monitors.
    public func start() {
        islandWindowController.show()
        volumeMonitor.startMonitoring()
        brightnessMonitor.startMonitoring()
        batteryMonitor.startMonitoring()
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
        alert.informativeText = "Version: 0.2 Unified Dynamic System\n\nActive Screen: \(islandWindowController.currentGeometry.hasNotch ? "MacBook Retina (Hardware Notch)" : "Standard Display (Fallback Anchor)")\nIdle Capsule: \(Int(islandWindowController.currentGeometry.collapsedSize.width))×\(Int(islandWindowController.currentGeometry.collapsedSize.height)) pt\n\nModules: Music, Volume, Brightness, Battery, Transfers, Downloads, Ecosystem."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }
    
    public func menuBarDidRequestAbout() {
        let alert = NSAlert()
        alert.messageText = "About AHK Dynamic Island"
        alert.informativeText = "AHK Dynamic Island v0.2\nNative Apple Silicon Dynamic Utility\n\nDesigned to almost disappear when idle and intelligently come alive when something matters."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    public func menuBarDidRequestQuit() {
        NSApplication.shared.terminate(nil)
    }
}
