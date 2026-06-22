import ApplicationServices
import Foundation

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPrompt() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }
}
