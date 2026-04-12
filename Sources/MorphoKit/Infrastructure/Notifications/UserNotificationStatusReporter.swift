import Foundation
import UserNotifications

public final class UserNotificationStatusReporter: StatusReporting {
    private let isEnabled: Bool
    private let messageResolver: (StatusEntry) -> String

    public init(
        messageResolver: @escaping (StatusEntry) -> String = { $0.messageKey }
    ) {
        self.messageResolver = messageResolver
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
        content.body = resolvedMessage(for: entry)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func resolvedMessage(for entry: StatusEntry) -> String {
        messageResolver(entry)
    }
}
