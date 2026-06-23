import Foundation

public enum StatusItemPresentation {
    public static let title = ""
    public static let thresholdMenuTitle = "Wiggle After"
    public static let wiggleDistanceMenuTitle = "Wiggle Distance"
    public static let permissionMissingMessage = "No Accessibility Permission"
    public static let statusRefreshInterval: TimeInterval = 1

    public static let thresholdPresetTitles: [TimeInterval: String] = [
        30: "after 30 seconds",
        60: "after 1 minute",
        300: "after 5 minutes"
    ]

    public static func iconResourceName(isEnabled: Bool) -> String {
        isEnabled ? "MenuBarIconShake" : "MenuBarIcon"
    }

    public static func permissionMessage(isAccessibilityTrusted: Bool) -> String? {
        isAccessibilityTrusted ? nil : permissionMissingMessage
    }

    public static func wiggleDistanceValueTitle(_ distance: Double) -> String {
        "\(Int(distance.rounded())) px"
    }

    public static func shouldRequestInitialAccessibilityPrompt(
        isAccessibilityTrusted: Bool,
        lastPromptedInstallToken: String?,
        currentInstallToken: String
    ) -> Bool {
        !isAccessibilityTrusted && lastPromptedInstallToken != currentInstallToken
    }
}
