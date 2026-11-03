import Foundation
import HabitatCore

/// A habit completed on a day (key of the done set).
struct DoneKey: Hashable {
    let habitID: UUID
    let day: DayKey
}

/// One segment of a day's donut: a habit that counts on the day.
struct DonutSegment: Identifiable, Hashable {
    let habitID: UUID
    let colorHex: String
    let isDone: Bool

    var id: UUID { habitID }
}

/// Start and end of a ring segment as fractions of a full turn, starting at 12 o'clock.
struct DonutArc: Equatable {
    let start: Double
    let end: Double
}

enum DonutGeometry {
    /// Gap between neighbouring segments, as a fraction of a turn.
    static let gapFraction = 0.03

    /// Equal arcs for `count` segments. One segment is a full ring (no gap); zero gives none.
    static func arcs(count: Int) -> [DonutArc] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [DonutArc(start: 0, end: 1)] }
        let slot = 1.0 / Double(count)
        return (0..<count).map { index in
            DonutArc(
                start: Double(index) * slot + gapFraction / 2,
                end: Double(index + 1) * slot - gapFraction / 2
            )
        }
    }
}

/// Everything the month grid needs to draw one day.
struct MonthDayCell: Identifiable, Hashable {
    let day: DayKey
    let isInMonth: Bool
    let isToday: Bool
    let isFuture: Bool
    let segments: [DonutSegment]

    var id: Int { day.serial }
    var activeCount: Int { segments.count }
    var doneCount: Int { segments.filter(\.isDone).count }
    /// `done/active`, e.g. `3/5`; read by UI tests.
    var valueText: String { "\(doneCount)/\(activeCount)" }
}

enum MonthCellBuilder {
    static let rows = 6
    static let columns = 7

    /// The month's Monday-first grid padded with following days to a fixed 6 rows.
    static func paddedGrid(for month: Month) -> [(day: DayKey, isInMonth: Bool)] {
        var cells = month.grid.map { (day: $0.day, isInMonth: $0.isInMonth) }
        while cells.count < rows * columns, let last = cells.last {
            cells.append((day: last.day.adding(days: 1), isInMonth: false))
        }
        return Array(cells.prefix(rows * columns))
    }

    /// Cells for the month. A habit counts on a day inside its lifetime; `filter` limits the
    /// donut to one habit.
    static func cells(
        month: Month,
        habits: [Habit],
        done: Set<DoneKey>,
        filter: UUID?,
        today: DayKey
    ) -> [MonthDayCell] {
        let shown = habits
            .filter { filter == nil || $0.id == filter }
            .sorted { $0.sortOrder < $1.sortOrder }
        return paddedGrid(for: month).map { entry in
            let segments = shown
                .filter { $0.isActive(on: entry.day) }
                .map { DonutSegment(
                    habitID: $0.id,
                    colorHex: $0.colorHex,
                    isDone: done.contains(DoneKey(habitID: $0.id, day: entry.day))
                ) }
            return MonthDayCell(
                day: entry.day,
                isInMonth: entry.isInMonth,
                isToday: entry.day == today,
                isFuture: entry.day > today,
                segments: segments
            )
        }
    }
}

/// Localised day names without `Date` arithmetic.
enum MonthSymbols {
    private static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func monthName(_ month: Int) -> String {
        calendar.monthSymbols[month - 1]
    }

    /// Full weekday name, e.g. "Monday".
    static func weekdayName(_ weekday: Weekday) -> String {
        calendar.weekdaySymbols[weekday.rawValue % 7]
    }

    /// Header text, Monday first; one letter when `compact`.
    static func header(_ weekday: Weekday, compact: Bool) -> String {
        let symbols = compact ? calendar.veryShortStandaloneWeekdaySymbols : calendar.shortStandaloneWeekdaySymbols
        return symbols[weekday.rawValue % 7]
    }

    static func title(_ month: Month) -> String {
        "\(monthName(month.month)) \(month.year)"
    }

    /// "Monday 2 November".
    static func dayName(_ day: DayKey) -> String {
        "\(weekdayName(day.weekday)) \(day.day) \(monthName(day.month))"
    }
}
