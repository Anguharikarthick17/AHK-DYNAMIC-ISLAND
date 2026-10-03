import Foundation

// Unbuffer stdio for native messaging protocol
setbuf(stdin, nil)
setbuf(stdout, nil)

let stdinHandle = FileHandle.standardInput
let stdoutHandle = FileHandle.standardOutput
let notificationName = NSNotification.Name("com.ahk.dynamicisland.chrome.media")

// Signal handlers for graceful exit
signal(SIGINT) { _ in exit(0) }
signal(SIGTERM) { _ in exit(0) }
signal(SIGPIPE, SIG_IGN)

func broadcastDisconnect() {
    let disconnectPayload = "{\"version\":1,\"source\":\"chrome\",\"provider\":\"youtube\",\"event\":\"disconnect\"}"
    DistributedNotificationCenter.default().postNotificationName(
        notificationName,
        object: "com.ahk.chrome.media.host",
        userInfo: ["payload": disconnectPayload],
        deliverImmediately: true
    )
}

// Read loop according to Chrome Native Messaging Specification
while true {
    let lengthData = stdinHandle.readData(ofLength: 4)
    if lengthData.count < 4 {
        // EOF received - Chrome tab or browser closed
        broadcastDisconnect()
        break
    }
    
    let rawLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
    let length = UInt32(littleEndian: rawLength)
    
    // Protection against excessive memory payloads (max 1 MB per spec)
    guard length > 0 && length <= 1_048_576 else {
        FileHandle.standardError.write(Data("[AHKChromeMediaHost] Invalid length received: \(length)\n".utf8))
        broadcastDisconnect()
        break
    }
    
    let payloadData = stdinHandle.readData(ofLength: Int(length))
    guard payloadData.count == Int(length) else {
        FileHandle.standardError.write(Data("[AHKChromeMediaHost] Incomplete payload received\n".utf8))
        broadcastDisconnect()
        break
    }
    
    guard let jsonString = String(data: payloadData, encoding: .utf8) else {
        continue
    }
    
    // Broadcast message to AHK Dynamic Island via macOS IPC
    DistributedNotificationCenter.default().postNotificationName(
        notificationName,
        object: "com.ahk.chrome.media.host",
        userInfo: ["payload": jsonString],
        deliverImmediately: true
    )
    
    // Echo acknowledgment response back to Chrome extension port
    let ackJson = "{\"status\":\"ok\"}"
    if let ackData = ackJson.data(using: .utf8) {
        var ackLength = UInt32(ackData.count).littleEndian
        let ackLengthData = Data(bytes: &ackLength, count: 4)
        stdoutHandle.write(ackLengthData)
        stdoutHandle.write(ackData)
    }
}

exit(0)
