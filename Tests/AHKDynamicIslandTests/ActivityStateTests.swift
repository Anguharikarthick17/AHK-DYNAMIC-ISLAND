import XCTest
import Foundation
@testable import AHKDynamicIslandCore

@MainActor
final class ActivityStateTests: XCTestCase {
    
    func testNowPlayingStateProperties() {
        let state = NowPlayingState(
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            isPlaying: true,
            playbackProgress: 0.5,
            duration: 244.0,
            elapsedTime: 122.0,
            appName: "Music"
        )
        
        XCTAssertEqual(state.title, "Midnight City")
        XCTAssertEqual(state.artist, "M83")
        XCTAssertEqual(state.album, "Hurry Up, We're Dreaming")
        XCTAssertEqual(state.playbackProgress, 0.5, accuracy: 0.01)
        XCTAssertEqual(state.duration, 244.0, accuracy: 0.01)
        XCTAssertEqual(state.elapsedTime, 122.0, accuracy: 0.01)
        XCTAssertTrue(state.isPlaying)
    }
    
    func testDownloadStateCalculations() {
        let dl = DownloadState(
            filename: "Update.dmg",
            bytesReceived: 50 * 1024 * 1024,
            totalBytes: 100 * 1024 * 1024,
            speedBytesPerSec: 10 * 1024 * 1024,
            isCompleted: false
        )
        
        XCTAssertEqual(dl.progress, 0.5, accuracy: 0.01)
        XCTAssertFalse(dl.isCompleted)
        XCTAssertEqual(dl.formattedProgress, "50%")
        XCTAssertEqual(dl.formattedSize, "50.0 MB / 100.0 MB")
    }
    
    func testFileTransferStateProperties() {
        let transfer = FileTransferState(
            filename: "Documents.zip",
            direction: .sending,
            bytesTransferred: 30 * 1024 * 1024,
            totalBytes: 100 * 1024 * 1024,
            transferRate: "5.0 MB/s",
            eta: "14s",
            isCompleted: false
        )
        
        XCTAssertEqual(transfer.direction, TransferDirection.sending)
        XCTAssertEqual(transfer.progress, 0.3, accuracy: 0.01)
        XCTAssertEqual(transfer.transferRate, "5.0 MB/s")
        XCTAssertEqual(transfer.eta, "14s")
        XCTAssertFalse(transfer.isCompleted)
    }
    
    func testBatteryInfoThresholds() {
        let normal = BatteryInfo(level: 0.85, isCharging: false, isPluggedIn: false)
        XCTAssertFalse(normal.isLow)
        XCTAssertFalse(normal.isCritical)
        
        let low = BatteryInfo(level: 0.18, isCharging: false, isPluggedIn: false)
        XCTAssertTrue(low.isLow)
        XCTAssertFalse(low.isCritical)
        
        let critical = BatteryInfo(level: 0.08, isCharging: false, isPluggedIn: false)
        XCTAssertTrue(critical.isLow)
        XCTAssertTrue(critical.isCritical)
        
        let charging = BatteryInfo(level: 0.15, isCharging: true, isPluggedIn: true)
        XCTAssertFalse(charging.isLow, "Charging battery should not trigger low battery warning")
        XCTAssertFalse(charging.isCritical)
    }
    
    func testVolumeMonitorReadout() {
        let monitor = VolumeMonitor()
        let result = monitor.getCurrentVolume()
        XCTAssertGreaterThanOrEqual(result.volume, 0.0)
        XCTAssertLessThanOrEqual(result.volume, 1.0)
    }
    
    func testActivityNotificationAction() {
        let coord = ActivityNotificationCoordinator()
        var receivedTitle: String?
        var receivedSubtitle: String?
        
        coord.onNotificationPosted = { title, subtitle, _ in
            receivedTitle = title
            receivedSubtitle = subtitle
        }
        
        coord.postNotification(title: "Download Finished", subtitle: "Saved to ~/Downloads")
        
        XCTAssertEqual(receivedTitle, "Download Finished")
        XCTAssertEqual(receivedSubtitle, "Saved to ~/Downloads")
    }
}
