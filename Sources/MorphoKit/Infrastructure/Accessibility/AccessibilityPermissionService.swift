import ApplicationServices
import Foundation

public final class AccessibilityPermissionService: AccessibilityPermissionChecking {
    public init() {}

    public func isTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        return AXIsProcessTrusted()
    }
}
