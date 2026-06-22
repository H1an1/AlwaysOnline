import Foundation

public struct ActivitySettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var checkInterval: TimeInterval
    public var idleThreshold: TimeInterval
    public var wiggleDistance: Double
    public var wiggleRepetitions: Int
    public var cooldown: TimeInterval

    public static let defaults = ActivitySettings(
        isEnabled: true,
        checkInterval: 10,
        idleThreshold: 60,
        wiggleDistance: 8,
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
        self.wiggleDistance = max(1, wiggleDistance)
        self.wiggleRepetitions = max(1, wiggleRepetitions)
        self.cooldown = max(1, cooldown)
    }
}
