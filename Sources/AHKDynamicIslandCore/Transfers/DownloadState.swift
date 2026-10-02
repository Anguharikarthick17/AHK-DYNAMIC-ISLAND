import Foundation

/// Represents the live state of an active download.
public struct DownloadState: Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let bytesReceived: Int64
    public let totalBytes: Int64
    public let progress: Double // 0.0 to 1.0
    public let speedBytesPerSec: Double
    public let isCompleted: Bool
    public let isFailed: Bool
    
    public init(
        id: UUID = UUID(),
        filename: String,
        bytesReceived: Int64,
        totalBytes: Int64,
        speedBytesPerSec: Double = 0.0,
        isCompleted: Bool = false,
        isFailed: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.bytesReceived = bytesReceived
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? min(Double(bytesReceived) / Double(totalBytes), 1.0) : 0.0
        self.speedBytesPerSec = speedBytesPerSec
        self.isCompleted = isCompleted
        self.isFailed = isFailed
    }
    
    public var formattedProgress: String {
        return "\(Int(progress * 100))%"
    }
    
    public var formattedSize: String {
        let mbReceived = Double(bytesReceived) / (1024.0 * 1024.0)
        let mbTotal = Double(totalBytes) / (1024.0 * 1024.0)
        if totalBytes > 0 {
            return String(format: "%.1f MB / %.1f MB", mbReceived, mbTotal)
        } else {
            return String(format: "%.1f MB", mbReceived)
        }
    }
}
