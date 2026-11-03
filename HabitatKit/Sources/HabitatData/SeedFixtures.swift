import Foundation
import HabitatCore
import SwiftData

/// Named data sets for `-seed <fixture>`. Everything is derived from the injected `today`
/// (fixed ids, fixed pattern), so the same day gives the same data.
public enum SeedFixture: String, CaseIterable, Sendable {
    /// No data.
    case empty
    /// Five habits (daily and weekly goals), a week of completions, two reminders.
    case typical
    /// Habits with known streaks: daily 10, daily 3 (today not done yet), weekly 4.
    case streaks

    /// Loads the fixture named `name` into an empty store; a store with data is left alone.
    @MainActor
    public static func load(named name: String, into context: ModelContext, today: DayKey) throws {
        guard let fixture = SeedFixture(rawValue: name) else { throw SeedError.unknownFixture(name) }
        try fixture.load(into: context, today: today)
    }

    @MainActor
    public func load(into context: ModelContext, today: DayKey) throws {
        guard try context.fetchCount(FetchDescriptor<HabitModel>()) == 0,
              try context.fetchCount(FetchDescriptor<ReminderModel>()) == 0 else { return }
        try DocumentStore(context: context).replace(with: document(today: today))
    }

    /// The fixture as an export document.
    public func document(today: DayKey) -> ExportDocument {
        switch self {
        case .empty: ExportDocument()
        case .typical: Self.typical(today: today)
        case .streaks: Self.streaks(today: today)
        }
    }

    // MARK: - Fixtures

    private static func id(_ group: Int, _ index: Int) -> UUID {
        let text = String(format: "00000000-0000-0000-%04d-%012d", group, index)
        return UUID(uuidString: text) ?? UUID()
    }

    private static func time(_ hour: Int, _ minute: Int) -> ReminderTime {
        guard let value = ReminderTime(hour: hour, minute: minute) else {
            preconditionFailure("fixture time \(hour):\(minute) is out of range")
        }
        return value
    }

    private struct HabitSpec {
        var name: String
        var color: String
        var goal: Goal
    }

    private static func typical(today: DayKey) -> ExportDocument {
        let created = today.adding(days: -28)
        let specs: [HabitSpec] = [
            HabitSpec(name: "Read", color: "#3B82F6", goal: .daily),
            HabitSpec(name: "Workout", color: "#EF4444", goal: .timesPerWeek(3)),
            HabitSpec(name: "Meditate", color: "#8B5CF6", goal: .daily),
            HabitSpec(name: "Water", color: "#06B6D4", goal: .daily),
            HabitSpec(name: "Call family", color: "#F59E0B", goal: .timesPerWeek(1))
        ]
        var habits: [Habit] = []
        var completions: [Completion] = []
        for (index, spec) in specs.enumerated() {
            let habit = Habit(
                id: id(1, index + 1), name: spec.name, colorHex: spec.color, goal: spec.goal,
                createdDay: created, sortOrder: index
            )
            habits.append(habit)
            // The last 7 days (today included): done when (habit index + days back) % 3 != 0.
            for back in 0..<7 where (index + back) % 3 != 0 {
                completions.append(Completion(habitID: habit.id, day: today.adding(days: -back)))
            }
        }
        let reminders = [
            Reminder(
                id: id(2, 1), kind: .general(label: "Plan the day"), time: time(8, 0),
                weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]
            ),
            Reminder(id: id(2, 2), kind: .habit(id(1, 1)), time: time(21, 0), weekdays: Set(Weekday.allCases))
        ]
        return ExportDocument(habits: habits, completions: completions, reminders: reminders)
    }

    private static func streaks(today: DayKey) -> ExportDocument {
        let weekStart = Week(containing: today).start
        let created = weekStart.adding(days: -7 * 5)
        let ten = Habit(
            id: id(1, 1), name: "Ten days", colorHex: "#10B981", goal: .daily, createdDay: created, sortOrder: 0
        )
        let three = Habit(
            id: id(1, 2), name: "Three days", colorHex: "#3B82F6", goal: .daily, createdDay: created, sortOrder: 1
        )
        let weekly = Habit(
            id: id(1, 3), name: "Four weeks", colorHex: "#F59E0B", goal: .timesPerWeek(3),
            createdDay: created, sortOrder: 2
        )
        var completions: [Completion] = []
        for back in 0..<10 { completions.append(Completion(habitID: ten.id, day: today.adding(days: -back))) }
        for back in 1...3 { completions.append(Completion(habitID: three.id, day: today.adding(days: -back))) }
        // Weeks 1...4 back: Monday, Wednesday, Friday. The current week stays empty.
        for weeksBack in 1...4 {
            let start = weekStart.adding(days: -7 * weeksBack)
            for offset in [0, 2, 4] {
                completions.append(Completion(habitID: weekly.id, day: start.adding(days: offset)))
            }
        }
        return ExportDocument(habits: [ten, three, weekly], completions: completions)
    }
}
