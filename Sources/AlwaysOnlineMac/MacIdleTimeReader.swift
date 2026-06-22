import CoreGraphics
import Foundation

struct MacIdleTimeReader {
    private let eventTypes: [CGEventType] = [
        .keyDown,
        .flagsChanged,
        .mouseMoved,
        .leftMouseDown,
        .leftMouseDragged,
        .rightMouseDown,
        .rightMouseDragged,
        .otherMouseDown,
        .otherMouseDragged,
        .scrollWheel
    ]

    func currentIdleDuration() -> TimeInterval {
        eventTypes
            .map {
                CGEventSource.secondsSinceLastEventType(
                    .combinedSessionState,
                    eventType: $0
                )
            }
            .min() ?? 0
    }
}
