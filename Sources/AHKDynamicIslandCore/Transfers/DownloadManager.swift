import Foundation

/// Manages active and simulated downloads initiated via AHK Dynamic Island.
public final class DownloadManager: NSObject, @unchecked Sendable, URLSessionDownloadDelegate {
    
    @MainActor public var onDownloadProgress: ((DownloadState) -> Void)?
    @MainActor public private(set) var activeDownloads: [UUID: DownloadState] = [:]
    
    private var urlSession: URLSession!
    
    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    /// Starts or simulates a download with progress tracking.
    @MainActor
    public func startDownload(filename: String, totalBytes: Int64) -> UUID {
        let id = UUID()
        let state = DownloadState(id: id, filename: filename, bytesReceived: 0, totalBytes: totalBytes)
        activeDownloads[id] = state
        onDownloadProgress?(state)
        return id
    }
    
    /// Updates live progress for an active download.
    @MainActor
    public func updateProgress(id: UUID, bytesReceived: Int64) {
        guard var state = activeDownloads[id] else { return }
        let isDone = (bytesReceived >= state.totalBytes)
        state = DownloadState(
            id: id,
            filename: state.filename,
            bytesReceived: bytesReceived,
            totalBytes: state.totalBytes,
            speedBytesPerSec: 2.4 * 1024 * 1024,
            isCompleted: isDone
        )
        activeDownloads[id] = state
        onDownloadProgress?(state)
        
        if isDone {
            // Auto clean up after completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.activeDownloads.removeValue(forKey: id)
            }
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let filename = downloadTask.response?.suggestedFilename ?? "Downloaded File"
        let total = downloadTask.countOfBytesExpectedToReceive
        let state = DownloadState(filename: filename, bytesReceived: total, totalBytes: total, isCompleted: true)
        DispatchQueue.main.async { [weak self] in
            self?.onDownloadProgress?(state)
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let filename = downloadTask.response?.suggestedFilename ?? "Downloading..."
        let state = DownloadState(
            filename: filename,
            bytesReceived: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            speedBytesPerSec: 1.5 * 1024 * 1024
        )
        DispatchQueue.main.async { [weak self] in
            self?.onDownloadProgress?(state)
        }
    }
}
