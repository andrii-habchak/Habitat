import Foundation
import HabitatCore
import Testing

/// `yyyy-MM-dd` to a day; records an issue for a typo instead of crashing.
func day(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) -> DayKey {
    guard let value = DayKey(text) else {
        Issue.record("bad test day \(text)", sourceLocation: sourceLocation)
        return DayKey(serial: 0)
    }
    return value
}

func days(_ texts: String...) -> Set<DayKey> {
    Set(texts.map { day($0) })
}

func time(_ hour: Int, _ minute: Int, sourceLocation: SourceLocation = #_sourceLocation) -> ReminderTime {
    guard let value = ReminderTime(hour: hour, minute: minute) else {
        Issue.record("bad test time \(hour):\(minute)", sourceLocation: sourceLocation)
        return ReminderTime(hour: 0, minute: 0).unsafelyUnwrappedForTests
    }
    return value
}

func uuid(_ suffix: Int) -> UUID {
    let tail = String(suffix)
    let padded = String(repeating: "0", count: max(0, 12 - tail.count)) + tail
    return UUID(uuidString: "00000000-0000-0000-0000-" + padded) ?? UUID()
}

func habit(
    _ index: Int,
    goal: Goal = .daily,
    created: String = "2026-01-01",
    archived: String? = nil,
    name: String? = nil
) -> Habit {
    Habit(
        id: uuid(index),
        name: name ?? "Habit \(index)",
        colorHex: "#3366CC",
        goal: goal,
        createdDay: day(created),
        archivedDay: archived.map { day($0) },
        sortOrder: index
    )
}

extension Optional {
    /// Only reached when a literal in a test is wrong (already recorded as an issue).
    var unsafelyUnwrappedForTests: Wrapped {
        switch self {
        case let .some(value): value
        case .none: preconditionFailure("unreachable test literal")
        }
    }
}
