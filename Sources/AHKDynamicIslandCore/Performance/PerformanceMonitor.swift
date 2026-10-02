import Darwin
import Foundation

/// Snapshot of the current process resource utilization.
public struct PerformanceSnapshot: Sendable, CustomStringConvertible {
    public let cpuPercentage: Double
    public let memoryUsageBytes: UInt64
    public let memoryUsageMB: Double
    public let timestamp: Date
    
    public init(cpuPercentage: Double, memoryUsageBytes: UInt64, timestamp: Date = Date()) {
        self.cpuPercentage = cpuPercentage
        self.memoryUsageBytes = memoryUsageBytes
        self.memoryUsageMB = Double(memoryUsageBytes) / (1024.0 * 1024.0)
        self.timestamp = timestamp
    }
    
    public var description: String {
        return String(format: "CPU: %.2f%% | Memory: %.2f MB", cpuPercentage, memoryUsageMB)
    }
}

/// On-demand performance instrumentation component.
/// Event-driven with zero background timers or idle polling.
public final class PerformanceMonitor: @unchecked Sendable {
    
    public static let shared = PerformanceMonitor()
    
    public init() {}
    
    /// Samples current process CPU and memory utilization on demand.
    public func sampleCurrentProcess() -> PerformanceSnapshot {
        let memoryBytes = getResidentMemoryBytes()
        let cpuPercent = getProcessCpuPercentage()
        return PerformanceSnapshot(cpuPercentage: cpuPercent, memoryUsageBytes: memoryBytes)
    }
    
    private func getResidentMemoryBytes() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return taskInfo.resident_size
        }
        return 0
    }
    
    private func getProcessCpuPercentage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let kerr = task_threads(mach_task_self_, &threadList, &threadCount)
        guard kerr == KERN_SUCCESS, let threads = threadList else {
            return 0.0
        }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount * UInt32(MemoryLayout<thread_t>.size)))
        }
        
        var totalCpu: Double = 0.0
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let infoErr = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    Darwin.thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            
            if infoErr == KERN_SUCCESS {
                if (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                    totalCpu += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }
        
        return totalCpu
    }
}
