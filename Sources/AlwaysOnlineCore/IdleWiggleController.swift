import Foundation

public enum WiggleDecisionReason: Equatable, Sendable {
    case disabled
    case belowThreshold
    case coolingDown
    case thresholdReached
}

public struct WiggleDecision: Equatable, Sendable {
    public let shouldWiggle: Bool
    public let reason: WiggleDecisionReason
}

public final class IdleWiggleController {
    private var lastWiggleAt: Date?

    public init() {}

    public func evaluate(
        idleDuration: TimeInterval,
        now: Date,
        settings: ActivitySettings
    ) -> WiggleDecision {
        guard settings.isEnabled else {
            return WiggleDecision(shouldWiggle: false, reason: .disabled)
        }

        guard idleDuration >= settings.idleThreshold else {
            return WiggleDecision(shouldWiggle: false, reason: .belowThreshold)
        }

        if let lastWiggleAt, now.timeIntervalSince(lastWiggleAt) < settings.cooldown {
            return WiggleDecision(shouldWiggle: false, reason: .coolingDown)
        }

        lastWiggleAt = now
        return WiggleDecision(shouldWiggle: true, reason: .thresholdReached)
    }

    public func resetCooldown() {
        lastWiggleAt = nil
    }
}
