import Foundation
import HabitatCore
import HabitatData
import UserNotifications

/// Handles the "Mark done" action of habit reminders and shows reminders while the app is
/// open. Installed by `HabitatApp` at launch (the delegate must be set before launch ends).
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let sync: ReminderSync

    init(sync: ReminderSync) {
        self.sync = sync
    }

    /// Becomes the notification centre's delegate; with the system scheduler it also
    /// registers the "Mark done" category.
    @MainActor
    func install() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        if let scheduler = sync.scheduler as? UserNotificationScheduler {
            scheduler.registerCategories()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UserNotificationScheduler.markDoneActionIdentifier else { return }
        let request = response.notification.request
        let habitText = request.content.userInfo[UserNotificationScheduler.habitIDKey] as? String
        guard let target = MarkDoneTarget(identifier: request.identifier, habitIDText: habitText) else { return }
        await sync.markDone(habitID: target.habitID, day: target.day)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Habit and day of a "Mark done" response. The request identifier is
/// `<reminder uuid>.<yyyy-MM-dd>` (`PlannedNotification.identifier`); the habit comes from
/// the request's `userInfo`.
struct MarkDoneTarget: Equatable, Sendable {
    let habitID: UUID
    let day: DayKey

    init?(identifier: String, habitIDText: String?) {
        guard let habitIDText, let habitID = UUID(uuidString: habitIDText),
              let separator = identifier.lastIndex(of: "."),
              UUID(uuidString: String(identifier[..<separator])) != nil,
              let day = DayKey(String(identifier[identifier.index(after: separator)...]))
        else { return nil }
        self.habitID = habitID
        self.day = day
    }
}
