import XCTest
@testable import AlwaysOnlineCore

final class IdleWiggleControllerTests: XCTestCase {
    func testDefaultWiggleDistanceIsLargeEnoughToBeVisible() {
        XCTAssertEqual(ActivitySettings.defaults.wiggleDistance, 16)
    }

    func testWiggleDistanceCannotExceedSliderMaximum() {
        let settings = ActivitySettings(
            isEnabled: true,
            checkInterval: 10,
            idleThreshold: 60,
            wiggleDistance: 240,
            wiggleRepetitions: 2,
            cooldown: 30
        )

        XCTAssertEqual(settings.wiggleDistance, ActivitySettings.maximumWiggleDistance)
        XCTAssertEqual(ActivitySettings.maximumWiggleDistance, 120)
    }

    func testDisabledSettingsNeverWiggle() {
        let controller = IdleWiggleController()
        let settings = ActivitySettings(
            isEnabled: false,
            checkInterval: 10,
            idleThreshold: 60,
            wiggleDistance: 8,
            wiggleRepetitions: 2,
            cooldown: 30
        )

        let decision = controller.evaluate(
            idleDuration: 120,
            now: Date(timeIntervalSince1970: 1_000),
            settings: settings
        )

        XCTAssertFalse(decision.shouldWiggle)
        XCTAssertEqual(decision.reason, .disabled)
    }

    func testIdleBelowThresholdDoesNotWiggle() {
        let controller = IdleWiggleController()
        let settings = ActivitySettings.defaults

        let decision = controller.evaluate(
            idleDuration: settings.idleThreshold - 1,
            now: Date(timeIntervalSince1970: 1_000),
            settings: settings
        )

        XCTAssertFalse(decision.shouldWiggle)
        XCTAssertEqual(decision.reason, .belowThreshold)
    }

    func testIdleAtThresholdWigglesAndRecordsCooldown() {
        let controller = IdleWiggleController()
        let settings = ActivitySettings.defaults
        let now = Date(timeIntervalSince1970: 1_000)

        let firstDecision = controller.evaluate(
            idleDuration: settings.idleThreshold,
            now: now,
            settings: settings
        )
        let secondDecision = controller.evaluate(
            idleDuration: settings.idleThreshold + 20,
            now: now.addingTimeInterval(5),
            settings: settings
        )

        XCTAssertTrue(firstDecision.shouldWiggle)
        XCTAssertEqual(firstDecision.reason, .thresholdReached)
        XCTAssertFalse(secondDecision.shouldWiggle)
        XCTAssertEqual(secondDecision.reason, .coolingDown)
    }

    func testCooldownExpiryAllowsAnotherWiggle() {
        let controller = IdleWiggleController()
        let settings = ActivitySettings.defaults
        let now = Date(timeIntervalSince1970: 1_000)

        _ = controller.evaluate(
            idleDuration: settings.idleThreshold,
            now: now,
            settings: settings
        )
        let decision = controller.evaluate(
            idleDuration: settings.idleThreshold + settings.cooldown,
            now: now.addingTimeInterval(settings.cooldown),
            settings: settings
        )

        XCTAssertTrue(decision.shouldWiggle)
        XCTAssertEqual(decision.reason, .thresholdReached)
    }
}
