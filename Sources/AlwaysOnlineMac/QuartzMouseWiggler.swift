import CoreGraphics
import Darwin
import Foundation

struct QuartzMouseWiggler {
    func wiggle(distance: Double, repetitions: Int) {
        guard let currentEvent = CGEvent(source: nil) else {
            return
        }

        let origin = currentEvent.location
        let shifted = CGPoint(x: origin.x + distance, y: origin.y)
        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<max(1, repetitions) {
            postMouseMove(to: shifted, source: source)
            usleep(80_000)
            postMouseMove(to: origin, source: source)
            usleep(80_000)
        }
    }

    private func postMouseMove(to point: CGPoint, source: CGEventSource?) {
        let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }
}
