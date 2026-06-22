import XCTest
@testable import AlwaysOnlineCore

final class StatusItemPresentationTests: XCTestCase {
    func testStatusTitleIsEmptyBecauseMenuBarUsesIconOnly() {
        XCTAssertEqual(StatusItemPresentation.title, "")
    }

    func testThresholdMenuTitleExplainsWhenItTriggers() {
        XCTAssertEqual(StatusItemPresentation.thresholdMenuTitle, "Wiggle After")
    }

    func testThresholdPresetTitlesExplainDurationUntilTrigger() {
        XCTAssertEqual(
            StatusItemPresentation.thresholdPresetTitles,
            [
                30: "after 30 seconds",
                60: "after 1 minute",
                300: "after 5 minutes"
            ]
        )
    }

    func testMenuBarIconResourceReflectsEnabledState() {
        XCTAssertEqual(
            StatusItemPresentation.iconResourceName(isEnabled: false),
            "MenuBarIcon"
        )
        XCTAssertEqual(
            StatusItemPresentation.iconResourceName(isEnabled: true),
            "MenuBarIconShake"
        )
    }

    func testPermissionMessageOnlyShowsWhenAccessibilityIsMissing() {
        XCTAssertEqual(
            StatusItemPresentation.permissionMessage(isAccessibilityTrusted: false),
            "No Accessibility Permission"
        )
        XCTAssertNil(StatusItemPresentation.permissionMessage(isAccessibilityTrusted: true))
    }

    func testAccessibilityPromptRunsOncePerInstallWhenPermissionIsMissing() {
        XCTAssertTrue(
            StatusItemPresentation.shouldRequestInitialAccessibilityPrompt(
                isAccessibilityTrusted: false,
                lastPromptedInstallToken: nil,
                currentInstallToken: "install-a"
            )
        )
        XCTAssertFalse(
            StatusItemPresentation.shouldRequestInitialAccessibilityPrompt(
                isAccessibilityTrusted: false,
                lastPromptedInstallToken: "install-a",
                currentInstallToken: "install-a"
            )
        )
        XCTAssertTrue(
            StatusItemPresentation.shouldRequestInitialAccessibilityPrompt(
                isAccessibilityTrusted: false,
                lastPromptedInstallToken: "install-a",
                currentInstallToken: "install-b"
            )
        )
        XCTAssertFalse(
            StatusItemPresentation.shouldRequestInitialAccessibilityPrompt(
                isAccessibilityTrusted: true,
                lastPromptedInstallToken: nil,
                currentInstallToken: "install-a"
            )
        )
    }

    func testStatusRefreshIntervalIsFastEnoughForPermissionChanges() {
        XCTAssertLessThanOrEqual(StatusItemPresentation.statusRefreshInterval, 1)
    }
}
