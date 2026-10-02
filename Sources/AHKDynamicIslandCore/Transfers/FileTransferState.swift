import Foundation

/// Direction of a file transfer.
public enum TransferDirection: String, Equatable, Sendable {
    case sending
    case receiving
}

/// Represents the live state of a file transfer.
public struct FileTransferState: Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let direction: TransferDirection
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public let progress: Double // 0.0 to 1.0
    public let transferRate: String // e.g. "14.2 MB/s"
    public let eta: String // e.g. "8s"
    public let isCompleted: Bool
    
    public init(
        id: UUID = UUID(),
        filename: String,
        direction: TransferDirection = .sending,
        bytesTransferred: Int64,
        totalBytes: Int64,
        transferRate: String = "12.0 MB/s",
        eta: String = "5s",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.direction = direction
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? min(Double(bytesTransferred) / Double(totalBytes), 1.0) : 0.0
        self.transferRate = transferRate
        self.eta = eta
        self.isCompleted = isCompleted
    }
}
