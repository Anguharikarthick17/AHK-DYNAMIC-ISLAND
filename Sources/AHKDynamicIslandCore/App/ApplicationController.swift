import AppKit
import Foundation

/// Central coordinator for the AHK Dynamic Island application in V0.2.
@MainActor
public final class ApplicationController: NSObject, MenuBarControllerDelegate {
    
    public let islandWindowController: IslandWindowController
    public let menuBarController: MenuBarController
    public let performanceMonitor: PerformanceMonitor
    
    // V0.2 & V0.3 Dynamic Activity Engines
    public let eventCoordinator: IslandEventCoordinator
    public let volumeMonitor: VolumeMonitor
    public let brightnessMonitor: BrightnessMonitor
    public let batteryMonitor: BatteryMonitor
    public let nowPlayingManager: NowPlayingManager
    public let downloadManager: DownloadManager
    public let fileTransferManager: FileTransferManager
    public let notificationCoordinator: ActivityNotificationCoordinator
    public let audioDeviceMonitor: AudioDeviceMonitor
    public let networkMonitor: NetworkMonitor
    public let clipboardProvider: ClipboardActivityProvider
    public let miniTimerManager: MiniTimerManager
    public let eventBus: AHKEventBus
    public let activityRegistry: UniversalActivityRegistry
    public let appObserver: UniversalApplicationObserver
    
    public init(
        islandWindowController: IslandWindowController = IslandWindowController(),
        menuBarController: MenuBarController = MenuBarController(),
        performanceMonitor: PerformanceMonitor = PerformanceMonitor.shared,
        eventCoordinator: IslandEventCoordinator = IslandEventCoordinator(),
        activityRegistry: UniversalActivityRegistry = UniversalActivityRegistry.shared
    ) {
        self.islandWindowController = islandWindowController
        self.menuBarController = menuBarController
        self.performanceMonitor = performanceMonitor
        self.eventCoordinator = eventCoordinator
        self.activityRegistry = activityRegistry
        self.appObserver = UniversalApplicationObserver(registry: activityRegistry)
        
        self.volumeMonitor = VolumeMonitor()
        self.brightnessMonitor = BrightnessMonitor()
        self.batteryMonitor = BatteryMonitor()
        self.nowPlayingManager = NowPlayingManager()
        self.downloadManager = DownloadManager()
        self.fileTransferManager = FileTransferManager()
        self.notificationCoordinator = ActivityNotificationCoordinator()
        self.audioDeviceMonitor = AudioDeviceMonitor()
        self.networkMonitor = NetworkMonitor()
        self.clipboardProvider = ClipboardActivityProvider()
        self.miniTimerManager = MiniTimerManager.shared
        self.eventBus = AHKEventBus.shared
        
        super.init()
        
        setupCoordination()
        wireActivityMonitors()
        wireApplicationObserver()
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
        // Battery & Smart Idle
        batteryMonitor.onBatteryStatusChanged = { [weak self] info in
            Task { @MainActor [weak self] in
                // Update smart idle secondary information
                DeviceIdentityManager.shared.updateSecondaryBattery(level: info.level, isCharging: info.isCharging)
                self?.islandWindowController.islandView.updateIdleIdentity()
                
                // Post battery activity when low, or critical
                if info.isLow || info.isCritical {
                    self?.eventCoordinator.postActivity(.battery(
                        level: info.level,
                        isCharging: info.isCharging,
                        isLow: info.isLow,
                        isCritical: info.isCritical
                    ))
                }
            }
        }
        
        // Charger Connect / Disconnect
        batteryMonitor.onChargerEvent = { [weak self] isConnected, percent in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.charger(isConnected: isConnected, percent: percent))
            }
        }
        
        // Audio Device Changes
        audioDeviceMonitor.onDeviceChanged = { [weak self] info in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.audioDevice(
                    name: info.name,
                    isConnected: info.isConnected,
                    icon: info.iconSymbol
                ))
            }
        }
        
        // Network State
        networkMonitor.onNetworkStateChanged = { [weak self] info in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.network(
                    statusText: info.statusText,
                    icon: info.iconSymbol,
                    isWarning: info.isWarning
                ))
            }
        }
        
        // Clipboard Activity
        clipboardProvider.onClipboardActivity = { [weak self] statusText in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.clipboard(statusText: statusText))
            }
        }
        
        // Mini Timers
        miniTimerManager.onTick = { [weak self] rem, tot in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.timer(
                    remainingSeconds: rem,
                    totalSeconds: tot,
                    isCompleted: false
                ))
            }
        }
        
        miniTimerManager.onComplete = { [weak self] tot in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.timer(
                    remainingSeconds: 0,
                    totalSeconds: tot,
                    isCompleted: true
                ))
            }
        }
        
        miniTimerManager.onCancelled = { [weak self] in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.removeActivities { act in
                    if case .timer = act { return true }
                    return false
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
                // Only post generic notification if it is not a rich live activity event
                if event.name != "activity" {
                    let title = event.payload["title"] ?? event.name
                    let subtitle = event.payload["subtitle"]
                    self?.eventCoordinator.postActivity(.notification(title: title, subtitle: subtitle, iconName: "sparkles"))
                }
            }
        }
    }
    
    private func wireApplicationObserver() {
        appObserver.onApplicationActivityDetected = { [weak self] activity in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.appActivity(activity: activity))
            }
        }
        
        appObserver.onApplicationTerminated = { [weak self] app in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.removeActivities { activity in
                    if case .appActivity(let a) = activity {
                        return a.bundleIdentifier == app.bundleIdentifier
                    }
                    return false
                }
            }
        }
        
        activityRegistry.onActivityRegistered = { [weak self] activity in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.appActivity(activity: activity))
            }
        }
        
        activityRegistry.onActivityUpdated = { [weak self] activity in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.postActivity(.appActivity(activity: activity))
            }
        }
        
        activityRegistry.onActivityRemoved = { [weak self] bundleID in
            Task { @MainActor [weak self] in
                self?.eventCoordinator.removeActivities { activity in
                    if case .appActivity(let a) = activity {
                        return a.bundleIdentifier == bundleID
                    }
                    return false
                }
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
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.resetIdle"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.eventCoordinator.removeActivities { _ in true }
                self?.eventCoordinator.clearCurrentActivity()
            }
        }
        
        // V0.4 IPC Handlers for Testing & Ecosystem Triggers
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerCharger"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let isConnected = (userInfo["isConnected"] as? Bool) ?? true
            let percent = (userInfo["percent"] as? Int) ?? 67
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.charger(isConnected: isConnected, percent: percent))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerAudioDevice"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let name = (userInfo["name"] as? String) ?? "AirPods Pro"
            let isConnected = (userInfo["isConnected"] as? Bool) ?? true
            let icon = (userInfo["icon"] as? String) ?? "airpodspro"
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.audioDevice(name: name, isConnected: isConnected, icon: icon))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerNetwork"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let statusText = (userInfo["statusText"] as? String) ?? "Internet Restored"
            let icon = (userInfo["icon"] as? String) ?? "checkmark.circle.fill"
            let isWarning = (userInfo["isWarning"] as? Bool) ?? false
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.network(statusText: statusText, icon: icon, isWarning: isWarning))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerTimer"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let duration = (userInfo["duration"] as? Double) ?? 300
            MainActor.assumeIsolated {
                self?.miniTimerManager.startTimer(duration: duration)
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerTimerComplete"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.timer(remainingSeconds: 0, totalSeconds: 300, isCompleted: true))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerClipboard"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let statusText = (userInfo["type"] as? String) ?? "Copied"
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.clipboard(statusText: statusText))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerDownload"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let filename = (userInfo["filename"] as? String) ?? "Update.dmg"
            let progress = (userInfo["progress"] as? Double) ?? 0.64
            let isCompleted = (userInfo["isCompleted"] as? Bool) ?? false
            let appName = userInfo["appName"] as? String
            let state = DownloadState(
                filename: filename,
                bytesReceived: Int64(progress * 10000000),
                totalBytes: 10000000,
                isCompleted: isCompleted,
                appName: appName
            )
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.download(state: state))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerNotification"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let title = (userInfo["title"] as? String) ?? "Discord"
            let subtitle = userInfo["subtitle"] as? String
            let icon = (userInfo["icon"] as? String) ?? "bell.fill"
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.notification(title: title, subtitle: subtitle, iconName: icon))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerMedia"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let title = (userInfo["title"] as? String) ?? "Blinding Lights"
            let artist = (userInfo["artist"] as? String) ?? "The Weeknd"
            let isPlaying = (userInfo["isPlaying"] as? Bool) ?? true
            let state = NowPlayingState(title: title, artist: artist, isPlaying: isPlaying)
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.nowPlaying(state: state))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerVolume"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let level = (userInfo["level"] as? Float) ?? 0.72
            let isMuted = (userInfo["isMuted"] as? Bool) ?? false
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.volume(level: level, isMuted: isMuted))
            }
        }
        center.addObserver(forName: NSNotification.Name("com.ahk.dynamicisland.triggerBrightness"), object: nil, queue: .main) { [weak self] notif in
            let userInfo = notif.userInfo as? [String: Any] ?? [:]
            let level = (userInfo["level"] as? Float) ?? 0.85
            MainActor.assumeIsolated {
                self?.eventCoordinator.postActivity(.brightness(level: level))
            }
        }
    }
    
    /// Starts the application and event monitors.
    public func start() {
        islandWindowController.show()
        volumeMonitor.startMonitoring()
        brightnessMonitor.startMonitoring()
        batteryMonitor.startMonitoring()
        audioDeviceMonitor.startMonitoring()
        networkMonitor.startMonitoring()
        clipboardProvider.startObserving()
        appObserver.startObserving()
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
        let devName = DeviceIdentityManager.shared.fullIdlePresentation
        let width = Int(DeviceIdentityManager.shared.idleCapsuleWidth)
        alert.informativeText = "Version: 0.4 Smart System Experience\nFeatures: 10 New System Intelligence Features\n\nActive Screen: \(islandWindowController.currentGeometry.hasNotch ? "MacBook Retina (Hardware Notch)" : "Standard Display (Fallback Anchor)")\nIdle Capsule: \(width)×26 pt (\(devName))\n\nSmart System Layer: Event-driven audio, network, battery intelligence, timers, and clipboard."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }
    
    public func menuBarDidRequestAbout() {
        let alert = NSAlert()
        alert.messageText = "About AHK Dynamic Island"
        let devName = DeviceIdentityManager.shared.fullIdlePresentation
        alert.informativeText = "AHK Dynamic Island v0.4\nNative Apple Silicon Dynamic Utility\n\nSmart System Experience (\(devName)) with 10 New System Intelligence Features."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    public func menuBarDidRequestQuit() {
        NSApplication.shared.terminate(nil)
    }
}
