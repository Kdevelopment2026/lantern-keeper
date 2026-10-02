import Foundation
import UserNotifications

enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}

/// Optional morning notification. The app is fully usable without it.
@MainActor
protocol NotificationService: AnyObject {
    func authorization() async -> NotificationAuthorization
    /// Only called after the user turns the notification on.
    func requestAuthorization() async -> NotificationAuthorization
    /// Replaces any pending watch notification.
    func scheduleWatchComplete(at date: Date) async
    func cancelWatchComplete()
}

enum NotificationCopy {
    static let watchComplete = String(localized: "Morning. Your watch is complete.")
}

@MainActor
final class UserNotificationService: NotificationService {
    nonisolated static let watchCompleteIdentifier = "watch.complete"

    func authorization() async -> NotificationAuthorization {
        Self.map(await Self.currentStatus())
    }

    func requestAuthorization() async -> NotificationAuthorization {
        let granted = await Self.request()
        return granted ? .allowed : Self.map(await Self.currentStatus())
    }

    func scheduleWatchComplete(at date: Date) async {
        guard await authorization() == .allowed else { return }
        cancelWatchComplete()
        await Self.add(at: date, body: NotificationCopy.watchComplete)
    }

    func cancelWatchComplete() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.watchCompleteIdentifier])
    }

    // System calls stay nonisolated so non-Sendable framework types never cross actors.

    private nonisolated static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private nonisolated static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private nonisolated static func add(at date: Date, body: String) async {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: watchCompleteIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}

@MainActor
final class FakeNotificationService: NotificationService {
    var status: NotificationAuthorization
    var responseToRequest: NotificationAuthorization
    private(set) var requestCount = 0
    private(set) var scheduledDate: Date?

    init(status: NotificationAuthorization = .notDetermined, responseToRequest: NotificationAuthorization = .allowed) {
        self.status = status
        self.responseToRequest = responseToRequest
    }

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async -> NotificationAuthorization {
        requestCount += 1
        status = responseToRequest
        return status
    }

    func scheduleWatchComplete(at date: Date) async {
        guard status == .allowed else { return }
        scheduledDate = date
    }

    func cancelWatchComplete() {
        scheduledDate = nil
    }
}
