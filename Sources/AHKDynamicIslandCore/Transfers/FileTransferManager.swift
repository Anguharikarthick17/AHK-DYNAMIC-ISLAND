import Foundation

/// Manages file transfers initiated by AHK Dynamic Island or ecosystem tools.
@MainActor
public final class FileTransferManager {
    
    public var onTransferProgress: ((FileTransferState) -> Void)?
    public private(set) var activeTransfers: [UUID: FileTransferState] = [:]
    
    public init() {}
    
    /// Starts tracking a file transfer.
    public func startTransfer(filename: String, direction: TransferDirection, totalBytes: Int64) -> UUID {
        let id = UUID()
        let state = FileTransferState(id: id, filename: filename, direction: direction, bytesTransferred: 0, totalBytes: totalBytes)
        activeTransfers[id] = state
        onTransferProgress?(state)
        return id
    }
    
    /// Updates live progress, speed, and ETA.
    public func updateProgress(id: UUID, bytesTransferred: Int64, rate: String = "15.4 MB/s", eta: String = "4s") {
        guard var state = activeTransfers[id] else { return }
        let isDone = (bytesTransferred >= state.totalBytes)
        state = FileTransferState(
            id: id,
            filename: state.filename,
            direction: state.direction,
            bytesTransferred: bytesTransferred,
            totalBytes: state.totalBytes,
            transferRate: rate,
            eta: eta,
            isCompleted: isDone
        )
        activeTransfers[id] = state
        onTransferProgress?(state)
        
        if isDone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.activeTransfers.removeValue(forKey: id)
            }
        }
    }
}
