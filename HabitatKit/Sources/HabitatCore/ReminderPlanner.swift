import Foundation

/// One notification request to schedule: a reminder on a concrete day.
public struct PlannedNotification: Hashable, Sendable {
    public let reminderID: UUID
    public let kind: ReminderKind
    public let day: DayKey
    public let time: ReminderTime

    /// Stable request identifier: `<reminder uuid>.<yyyy-MM-dd>`.
    public var identifier: String { reminderID.uuidString + "." + day.text }
}

/// Turns reminders into concrete notification requests (PLAN §2, R-REM). Pure: the caller
/// re-plans on app open and on every toggle and replaces all pending requests.
public enum ReminderPlanner {
    /// Days planned ahead, today included.
    public static let windowDays = 14
    /// Upper bound on pending requests (the system keeps at most 64).
    public static let maxRequests = 60

    /// - Parameters:
    ///   - now: the current local moment; times today at or before `now` are skipped.
    ///   - habits: habits by id; a habit reminder is skipped for a missing habit, on days
    ///     the habit is not active (before created, after archived) and on done days.
    ///   - completions: done days.
    /// - Returns: the earliest requests first, at most `maxRequests`.
    public static func plan(
        reminders: [Reminder],
        habits: [Habit],
        completions: [Completion],
        now: LocalMoment,
        windowDays: Int = windowDays,
        maxRequests: Int = maxRequests
    ) -> [PlannedNotification] {
        let habitsByID = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let done = Set(completions)
        var planned: [PlannedNotification] = []
        for offset in 0..<max(0, windowDays) {
            let day = now.day.adding(days: offset)
            for reminder in reminders where reminder.weekdays.contains(day.weekday) {
                if offset == 0, reminder.time.minuteOfDay <= now.minuteOfDay { continue }
                if let habitID = reminder.kind.habitID {
                    guard let habit = habitsByID[habitID], habit.isActive(on: day),
                          !done.contains(Completion(habitID: habitID, day: day))
                    else { continue }
                }
                planned.append(PlannedNotification(
                    reminderID: reminder.id, kind: reminder.kind, day: day, time: reminder.time
                ))
            }
        }
        planned.sort { lhs, rhs in
            (lhs.day, lhs.time.minuteOfDay, lhs.reminderID.uuidString)
                < (rhs.day, rhs.time.minuteOfDay, rhs.reminderID.uuidString)
        }
        return Array(planned.prefix(max(0, maxRequests)))
    }
}
