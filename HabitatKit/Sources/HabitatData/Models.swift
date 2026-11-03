import Foundation
import HabitatCore
import SwiftData

/// Persisted habit. Days are stored as `DayKey.serial` integers, never as `Date`.
@Model
public final class HabitModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    /// `nil` = daily, otherwise the weekly target (1...7).
    public var timesPerWeek: Int?
    public var createdDaySerial: Int
    public var archivedDaySerial: Int?
    public var sortOrder: Int

    public init(_ habit: Habit) {
        id = habit.id
        name = habit.name
        colorHex = habit.colorHex
        timesPerWeek = Self.timesPerWeek(of: habit.goal)
        createdDaySerial = habit.createdDay.serial
        archivedDaySerial = habit.archivedDay?.serial
        sortOrder = habit.sortOrder
    }

    /// Copies every field of `habit` onto the model.
    func apply(_ habit: Habit) {
        name = habit.name
        colorHex = habit.colorHex
        timesPerWeek = Self.timesPerWeek(of: habit.goal)
        createdDaySerial = habit.createdDay.serial
        archivedDaySerial = habit.archivedDay?.serial
        sortOrder = habit.sortOrder
    }

    public var value: Habit {
        Habit(
            id: id,
            name: name,
            colorHex: colorHex,
            goal: timesPerWeek.map { Goal.timesPerWeek($0) } ?? .daily,
            createdDay: DayKey(serial: createdDaySerial),
            archivedDay: archivedDaySerial.map { DayKey(serial: $0) },
            sortOrder: sortOrder
        )
    }

    private static func timesPerWeek(of goal: Goal) -> Int? {
        if case let .timesPerWeek(count) = goal { return count }
        return nil
    }
}

/// Persisted "habit done on a day". `key` makes (habit, day) unique.
@Model
public final class CompletionModel {
    @Attribute(.unique) public var key: String
    public var habitID: UUID
    public var daySerial: Int

    public init(_ completion: Completion) {
        key = Self.key(for: completion)
        habitID = completion.habitID
        daySerial = completion.day.serial
    }

    public var value: Completion {
        Completion(habitID: habitID, day: DayKey(serial: daySerial))
    }

    static func key(for completion: Completion) -> String {
        completion.habitID.uuidString + "|" + String(completion.day.serial)
    }
}

/// Persisted reminder. `habitID == nil` means a general reminder (with `label`).
@Model
public final class ReminderModel {
    @Attribute(.unique) public var id: UUID
    public var label: String?
    public var habitID: UUID?
    public var hour: Int
    public var minute: Int
    /// Bit `n - 1` set for ISO weekday `n` (Monday = 1 ... Sunday = 7).
    public var weekdayMask: Int

    public init(_ reminder: Reminder) {
        id = reminder.id
        hour = reminder.time.hour
        minute = reminder.time.minute
        weekdayMask = 0
        apply(reminder)
    }

    func apply(_ reminder: Reminder) {
        switch reminder.kind {
        case let .general(text):
            label = text
            habitID = nil
        case let .habit(habit):
            label = nil
            habitID = habit
        }
        hour = reminder.time.hour
        minute = reminder.time.minute
        weekdayMask = reminder.weekdays.reduce(0) { $0 | (1 << ($1.rawValue - 1)) }
    }

    public var value: Reminder {
        let kind: ReminderKind = habitID.map { .habit($0) } ?? .general(label: label ?? "")
        let weekdays = Set(Weekday.allCases.filter { weekdayMask & (1 << ($0.rawValue - 1)) != 0 })
        // Hour and minute only ever come from a validated `ReminderTime`.
        guard let time = ReminderTime(hour: hour, minute: minute) else {
            preconditionFailure("stored reminder time \(hour):\(minute) is out of range")
        }
        return Reminder(id: id, kind: kind, time: time, weekdays: weekdays)
    }
}
