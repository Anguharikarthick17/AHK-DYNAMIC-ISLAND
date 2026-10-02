import XCTest
import Foundation
@testable import AHKDynamicIslandCore

@MainActor
final class EventCoordinatorTests: XCTestCase {
    
    func testPriorityOrdering() {
        XCTAssertGreaterThan(ActivityPriority.criticalAlert.rawValue, ActivityPriority.download.rawValue)
        XCTAssertGreaterThan(ActivityPriority.download.rawValue, ActivityPriority.fileTransfer.rawValue)
        XCTAssertGreaterThan(ActivityPriority.fileTransfer.rawValue, ActivityPriority.battery.rawValue)
        XCTAssertGreaterThan(ActivityPriority.battery.rawValue, ActivityPriority.nowPlaying.rawValue)
        XCTAssertGreaterThan(ActivityPriority.nowPlaying.rawValue, ActivityPriority.volume.rawValue)
        XCTAssertGreaterThan(ActivityPriority.volume.rawValue, ActivityPriority.idle.rawValue)
    }
    
    func testInitialStateIsIdle() {
        let coordinator = IslandEventCoordinator()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }
    
    func testPostingTransientActivity() {
        let coordinator = IslandEventCoordinator()
        var presentedActivity: IslandActivity?
        coordinator.onActivityChanged = { act in
            presentedActivity = act
        }
        
        let vol = IslandActivity.volume(level: 0.8, isMuted: false)
        coordinator.postActivity(vol)
        
        XCTAssertEqual(coordinator.activeActivity, vol)
        XCTAssertEqual(presentedActivity, vol)
    }
    
    func testHigherPriorityPreemptsLowerPriority() {
        let coordinator = IslandEventCoordinator()
        
        // Post media event (priority = nowPlaying)
        let mediaState = NowPlayingState(title: "Track", artist: "Artist")
        let mediaAct = IslandActivity.nowPlaying(state: mediaState)
        coordinator.postActivity(mediaAct)
        XCTAssertEqual(coordinator.activeActivity, mediaAct)
        
        // Post critical battery event (priority = criticalAlert)
        let batteryAct = IslandActivity.battery(level: 0.05, isCharging: false, isLow: true, isCritical: true)
        coordinator.postActivity(batteryAct)
        
        // Critical battery takes immediate priority
        XCTAssertEqual(coordinator.activeActivity, batteryAct)
    }
    
    func testLowerPriorityDoesNotPreemptHigherPriority() {
        let coordinator = IslandEventCoordinator()
        
        // Post critical battery alert
        let batteryAct = IslandActivity.battery(level: 0.05, isCharging: false, isLow: true, isCritical: true)
        coordinator.postActivity(batteryAct)
        
        // Post lower-priority volume event
        coordinator.postActivity(.volume(level: 0.5, isMuted: false))
        
        // Critical battery must remain displayed
        XCTAssertEqual(coordinator.activeActivity, batteryAct)
    }
    
    func testClearActivityRestoresPreviousOrIdle() {
        let coordinator = IslandEventCoordinator()
        
        let mediaState = NowPlayingState(title: "Track", artist: "Artist")
        let mediaAct = IslandActivity.nowPlaying(state: mediaState)
        coordinator.postActivity(mediaAct)
        
        // Transient notification preempts media
        let notifAct = IslandActivity.notification(title: "Notice", subtitle: "Test", iconName: "bell.fill")
        coordinator.postActivity(notifAct)
        XCTAssertEqual(coordinator.activeActivity, notifAct)
        
        // Clearing notification restores media
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, mediaAct)
        
        // Clearing media restores idle
        coordinator.clearCurrentActivity()
        XCTAssertEqual(coordinator.activeActivity, .idle)
    }
    
    func testAutoDismissDurationPerActivity() {
        let volumeAct = IslandActivity.volume(level: 0.5, isMuted: false)
        XCTAssertEqual(volumeAct.autoDismissInterval ?? 0, 1.8, accuracy: 0.01)
        
        let brightnessAct = IslandActivity.brightness(level: 0.6)
        XCTAssertEqual(brightnessAct.autoDismissInterval ?? 0, 1.8, accuracy: 0.01)
        
        let mediaAct = IslandActivity.nowPlaying(state: NowPlayingState(title: "T", artist: "A"))
        XCTAssertNil(mediaAct.autoDismissInterval, "NowPlaying should stay active until changed or dismissed")
        
        let downloadAct = IslandActivity.download(state: DownloadState(filename: "f.zip", bytesReceived: 10, totalBytes: 20))
        XCTAssertNil(downloadAct.autoDismissInterval, "Ongoing download should stay active while downloading")
        
        let completedDl = IslandActivity.download(state: DownloadState(filename: "f.zip", bytesReceived: 20, totalBytes: 20, isCompleted: true))
        XCTAssertEqual(completedDl.autoDismissInterval ?? 0, 2.0, accuracy: 0.01, "Completed download auto collapses after brief celebration")
    }
}
