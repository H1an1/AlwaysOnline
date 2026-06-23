import Foundation

public struct ActivitySettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var checkInterval: TimeInterval
    public var idleThreshold: TimeInterval
    public var wiggleDistance: Double
    public var wiggleRepetitions: Int
    public var cooldown: TimeInterval

    public static let minimumWiggleDistance: Double = 1
    public static let maximumWiggleDistance: Double = 120

    public static let defaults = ActivitySettings(
        isEnabled: true,
        checkInterval: 10,
        idleThreshold: 60,
        wiggleDistance: 16,
        wiggleRepetitions: 2,
        cooldown: 30
    )

    public init(
        isEnabled: Bool,
        checkInterval: TimeInterval,
        idleThreshold: TimeInterval,
        wiggleDistance: Double,
        wiggleRepetitions: Int,
        cooldown: TimeInterval
    ) {
        self.isEnabled = isEnabled
        self.checkInterval = max(1, checkInterval)
        self.idleThreshold = max(1, idleThreshold)
        self.wiggleDistance = Self.clampedWiggleDistance(wiggleDistance)
        self.wiggleRepetitions = max(1, wiggleRepetitions)
        self.cooldown = max(1, cooldown)
    }

    public static func clampedWiggleDistance(_ value: Double) -> Double {
        guard value.isFinite else {
            return minimumWiggleDistance
        }

        return min(maximumWiggleDistance, max(minimumWiggleDistance, value))
    }
}
