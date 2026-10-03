import Foundation

/// Content type classification for privacy-safe clipboard events.
/// Never contains the actual clipboard contents.
public enum ClipboardContentType: String, Sendable {
    case generic = "Copied"
    case text = "Text Copied"
    case image = "Image Copied"
    case file = "File Copied"
}

/// Privacy-safe clipboard activity provider.
///
/// PRIVACY & PERFORMANCE ARCHITECTURE:
/// - Never inspects, logs, stores, or transmits clipboard contents.
/// - Never creates a polling loop on NSPasteboard.changeCount.
/// - Listens exclusively to event-driven cooperative AHK EventBus notifications
///   (`com.ahk.event.clipboard.copied`).
/// - Generic OS-level pasteboard polling remains strictly inactive as macOS does not provide
///   a public global event-driven push notification without polling or accessibility permissions.
@MainActor
public final class ClipboardActivityProvider {
    
    public var onClipboardActivity: ((String) -> Void)?
    private var isObserving = false
    
    public init() {}
    
    public func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        AHKEventBus.shared.subscribe { [weak self] event in
            guard event.name == "clipboard.copied" || event.name == "com.ahk.event.clipboard.copied" else { return }
            let typeStr = event.payload["type"] ?? "generic"
            let statusText: String
            switch typeStr.lowercased() {
            case "text": statusText = ClipboardContentType.text.rawValue
            case "image": statusText = ClipboardContentType.image.rawValue
            case "file": statusText = ClipboardContentType.file.rawValue
            default: statusText = ClipboardContentType.generic.rawValue
            }
            Task { @MainActor [weak self] in
                self?.onClipboardActivity?(statusText)
            }
        }
    }
    
    public func stopObserving() {
        isObserving = false
    }
    
    /// Posts a privacy-safe copy event explicitly (e.g. from AHK utilities or testing).
    public func postCopyEvent(type: ClipboardContentType = .generic) {
        onClipboardActivity?(type.rawValue)
    }
}
