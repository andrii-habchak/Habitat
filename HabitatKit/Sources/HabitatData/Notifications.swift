import Foundation
import HabitatCore
import UserNotifications

public enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// One local notification to schedule: a reminder on a concrete day (local wall-clock time).
public struct NotificationRequestContent: Hashable, Sendable {
    /// `<reminder uuid>.<yyyy-MM-dd>`, see `PlannedNotification.identifier`.
    public var identifier: String
    public var title: String
    public var body: String
    public var day: DayKey
    public var time: ReminderTime
    /// The habit for a habit reminder; used by the "Mark done" action.
    public var habitID: UUID?

    public init(identifier: String, title: String, body: String, day: DayKey, time: ReminderTime, habitID: UUID?) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.day = day
        self.time = time
        self.habitID = habitID
    }
}

/// Scheduling of local notifications behind a protocol, so tests and `-fakeNotifications`
/// never touch the system.
public protocol NotificationScheduling: Sendable {
    func authorizationStatus() async -> NotificationAuthorization
    /// Asks the system for permission; returns whether it was granted.
    func requestAuthorization() async throws -> Bool
    func removeAllPendingRequests() async
    func add(_ requests: [NotificationRequestContent]) async throws
}

/// Re-plans reminders and swaps the pending requests (call on app open and after every toggle).
public enum NotificationSync {
    /// Plans with `ReminderPlanner` and replaces *all* pending requests with the result.
    /// Returns what was scheduled.
    @discardableResult
    public static func replaceAllPending(
        using scheduler: any NotificationScheduling,
        reminders: [Reminder],
        habits: [Habit],
        completions: [Completion],
        now: LocalMoment
    ) async throws -> [NotificationRequestContent] {
        let planned = ReminderPlanner.plan(reminders: reminders, habits: habits, completions: completions, now: now)
        let names = Dictionary(habits.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let requests = planned.map { item -> NotificationRequestContent in
            switch item.kind {
            case let .general(label):
                NotificationRequestContent(
                    identifier: item.identifier, title: label, body: "Reminder",
                    day: item.day, time: item.time, habitID: nil
                )
            case let .habit(id):
                NotificationRequestContent(
                    identifier: item.identifier, title: names[id] ?? "Habit",
                    body: "Time for \(names[id] ?? "your habit")", day: item.day, time: item.time, habitID: id
                )
            }
        }
        await scheduler.removeAllPendingRequests()
        try await scheduler.add(requests)
        return requests
    }
}

/// Records every call instead of scheduling anything (tests, `-fakeNotifications`).
public actor FakeNotificationScheduler: NotificationScheduling {
    public enum Call: Equatable, Sendable {
        case authorizationStatus
        case requestAuthorization
        case removeAllPendingRequests
        case add([NotificationRequestContent])
    }

    public private(set) var calls: [Call] = []
    /// What is "pending" right now: add appends, remove clears.
    public private(set) var pending: [NotificationRequestContent] = []
    public var status: NotificationAuthorization
    /// What `requestAuthorization()` answers (and the status it moves to).
    public var grantsAuthorization: Bool

    public init(status: NotificationAuthorization = .authorized, grantsAuthorization: Bool = true) {
        self.status = status
        self.grantsAuthorization = grantsAuthorization
    }

    public func authorizationStatus() async -> NotificationAuthorization {
        calls.append(.authorizationStatus)
        return status
    }

    public func requestAuthorization() async throws -> Bool {
        calls.append(.requestAuthorization)
        status = grantsAuthorization ? .authorized : .denied
        return grantsAuthorization
    }

    public func removeAllPendingRequests() async {
        calls.append(.removeAllPendingRequests)
        pending = []
    }

    public func add(_ requests: [NotificationRequestContent]) async throws {
        calls.append(.add(requests))
        pending += requests
    }
}

/// The system implementation. Not wired to any UI yet (P6). Requests fire once, on a
/// calendar date in the device's time zone.
public struct UserNotificationScheduler: NotificationScheduling {
    public static let categoryIdentifier = "habitat.habitReminder"
    public static let markDoneActionIdentifier = "habitat.markDone"
    public static let habitIDKey = "habitID"

    public init() {}

    public func authorizationStatus() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized
        }
    }

    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    public func removeAllPendingRequests() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    public func add(_ requests: [NotificationRequestContent]) async throws {
        let center = UNUserNotificationCenter.current()
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            if let habitID = request.habitID {
                content.categoryIdentifier = Self.categoryIdentifier
                content.userInfo = [Self.habitIDKey: habitID.uuidString]
            }
            var components = DateComponents()
            components.year = request.day.year
            components.month = request.day.month
            components.day = request.day.day
            components.hour = request.time.hour
            components.minute = request.time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let notification = UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            try await center.add(notification)
        }
    }

    /// Registers the "Mark done" action category (call once at launch from P6).
    public func registerCategories() {
        let action = UNNotificationAction(identifier: Self.markDoneActionIdentifier, title: "Mark done", options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier, actions: [action], intentIdentifiers: [], options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
