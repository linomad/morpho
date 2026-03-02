import Foundation
import UserNotifications

public final class UserNotificationStatusReporter: StatusReporting {
    private let isEnabled: Bool

    public init() {
        isEnabled = Bundle.main.bundleIdentifier != nil
        guard isEnabled else {
            return
        }

        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    public func publish(_ entry: StatusEntry) {
        guard isEnabled else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Morpho"
        content.body = entry.message

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
