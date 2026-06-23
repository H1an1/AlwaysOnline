import ApplicationServices
import Foundation

enum AccessibilityPermission {
    static var isTrusted: Bool {
        checkTrust(prompt: false)
    }

    @discardableResult
    static func requestPrompt() -> Bool {
        checkTrust(prompt: true)
    }

    private static func checkTrust(prompt: Bool) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }
}
