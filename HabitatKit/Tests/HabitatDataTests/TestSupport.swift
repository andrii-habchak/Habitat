import Foundation
import HabitatCore
import HabitatData
import SwiftData
import Testing

func day(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) -> DayKey {
    guard let value = DayKey(text) else {
        Issue.record("bad test day \(text)", sourceLocation: sourceLocation)
        return DayKey(serial: 0)
    }
    return value
}

func time(_ hour: Int, _ minute: Int, sourceLocation: SourceLocation = #_sourceLocation) -> ReminderTime {
    guard let value = ReminderTime(hour: hour, minute: minute) else {
        Issue.record("bad test time \(hour):\(minute)", sourceLocation: sourceLocation)
        return ReminderTime(hour: 0, minute: 0) ?? time(0, 0)
    }
    return value
}

/// 2026-03-11 is a Wednesday.
let testToday = day("2026-03-11")

/// An in-memory store with repositories on a fixed clock.
@MainActor
struct TestStore {
    let container: ModelContainer
    let clock: FixedClock
    let habits: HabitRepository
    let completions: CompletionRepository
    let reminders: ReminderRepository
    let transfer: DataTransfer

    var context: ModelContext { container.mainContext }

    init(today: DayKey = testToday) throws {
        container = try HabitatStore.makeContainer(StoreConfiguration(inMemory: true))
        clock = FixedClock(day: today)
        let context = container.mainContext
        habits = HabitRepository(context: context, clock: clock)
        completions = CompletionRepository(context: context, clock: clock)
        reminders = ReminderRepository(context: context)
        transfer = DataTransfer(context: context)
    }

    func addHabit(_ name: String = "Read", goal: Goal = .daily) throws -> Habit {
        try habits.create(name: name, colorHex: "#3366CC", goal: goal)
    }

    func snapshot() throws -> ExportDocument {
        try transfer.exportDocument()
    }
}
