import Foundation
import HabitatCore
import Testing

@Suite("Week math")
struct WeekTests {
    @Test("R-WEEK: every day of a week maps to its Monday", arguments: [
        "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"
    ])
    func containing(_ text: String) {
        let week = Week(containing: day(text))
        #expect(week.start == day("2026-11-02"))
        #expect(week.end == day("2026-11-08"))
        #expect(week.contains(day(text)))
    }

    @Test("R-WEEK: Monday boundary: Sunday ends a week, Monday starts the next")
    func mondayBoundary() {
        #expect(Week(containing: day("2026-11-08")).start == day("2026-11-02"))
        #expect(Week(containing: day("2026-11-09")).start == day("2026-11-09"))
        #expect(!Week(containing: day("2026-11-08")).contains(day("2026-11-09")))
        #expect(!Week(containing: day("2026-11-09")).contains(day("2026-11-08")))
    }

    @Test("R-WEEK: weeks across year ends and DST changes", arguments: [
        ("2026-01-01", "2025-12-29"), ("2027-01-03", "2026-12-28"), ("2024-02-29", "2024-02-26"),
        ("2026-03-29", "2026-03-23"), ("2026-03-30", "2026-03-30"), ("2026-10-25", "2026-10-19"),
        ("2026-10-26", "2026-10-26"), ("2026-03-01", "2026-02-23")
    ] as [(String, String)])
    func boundaries(_ text: String, _ monday: String) {
        let week = Week(containing: day(text))
        #expect(week.start == day(monday))
        #expect(week.start.weekday == .monday)
        #expect(week.end.weekday == .sunday)
        #expect(week.days.count == 7)
        #expect(week.days.first == week.start)
        #expect(week.days.last == week.end)
    }

    @Test("R-WEEK: Monday-first regardless of locale, same as Foundation with firstWeekday 2")
    func matchesFoundationMondayFirst() throws {
        #expect(Week.firstWeekday == 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        calendar.firstWeekday = Week.firstWeekday
        calendar.locale = Locale(identifier: "en_US")
        let first = day("2025-12-01")
        let origin = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 1, hour: 12)))
        for offset in 0..<800 {
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: origin))
            let interval = try #require(calendar.dateInterval(of: .weekOfYear, for: date))
            let parts = calendar.dateComponents([.year, .month, .day], from: interval.start)
            let start = Week(containing: first.adding(days: offset)).start
            #expect(start == DayKey(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0))
        }
    }

    @Test("R-WEEK: previous, next and offsets")
    func navigation() {
        let week = Week(containing: day("2026-11-03"))
        #expect(week.previous.start == day("2026-10-26"))
        #expect(week.next.start == day("2026-11-09"))
        #expect(week.adding(weeks: -9).start == day("2026-08-31"))
        #expect(week.adding(weeks: 0) == week)
        #expect(week.previous < week)
        #expect(week.next.previous == week)
    }

    @Test("R-WEEK: days left including today; 7 before the week, 0 once finished")
    func daysLeft() {
        let week = Week(containing: day("2026-11-03"))
        #expect(week.daysLeft(today: day("2026-11-02")) == 7)
        #expect(week.daysLeft(today: day("2026-11-03")) == 6)
        #expect(week.daysLeft(today: day("2026-11-08")) == 1)
        #expect(week.daysLeft(today: day("2026-11-09")) == 0)
        #expect(week.daysLeft(today: day("2026-10-30")) == 7)
    }
}

@Suite("Month math")
struct MonthTests {
    @Test("R-MONTH: days in month incl. leap February", arguments: [
        (2026, 1, 31), (2026, 2, 28), (2024, 2, 29), (2000, 2, 29), (1900, 2, 28), (2100, 2, 28),
        (2026, 4, 30), (2026, 6, 30), (2026, 9, 30), (2026, 11, 30), (2026, 12, 31), (2026, 7, 31)
    // swiftlint:disable:next large_tuple
    ] as [(Int, Int, Int)])
    func numberOfDays(_ year: Int, _ month: Int, _ count: Int) throws {
        let value = try #require(Month(year: year, month: month))
        #expect(value.numberOfDays == count)
        #expect(value.days.count == count)
        #expect(value.lastDay.day == count)
        #expect(value.firstDay.day == 1)
        #expect(value.lastDay.adding(days: 1).day == 1)
    }

    @Test("R-MONTH: invalid months are rejected",
          arguments: [(2026, 0), (2026, 13), (0, 5), (10_000, 1)] as [(Int, Int)])
    func invalid(_ year: Int, _ month: Int) {
        #expect(Month(year: year, month: month) == nil)
    }

    @Test("R-MONTH: November 2026 grid has 6 leading and 6 trailing days")
    func gridNovember2026() throws {
        let month = try #require(Month(year: 2026, month: 11))
        let grid = month.grid
        #expect(grid.count == 42)
        #expect(grid.first?.day == day("2026-10-26"))
        #expect(grid.last?.day == day("2026-12-06"))
        #expect(grid.prefix(6).allSatisfy { !$0.isInMonth })
        #expect(grid[6] == MonthGridCell(day: day("2026-11-01"), isInMonth: true))
        #expect(grid.suffix(6).allSatisfy { !$0.isInMonth })
        #expect(grid.filter { $0.isInMonth }.count == 30)
    }

    @Test("R-MONTH: February 2021 fills exactly four rows")
    func gridFebruary2021() throws {
        let grid = try #require(Month(year: 2021, month: 2)).grid
        #expect(grid.count == 28)
        #expect(grid.allSatisfy { $0.isInMonth })
    }

    @Test("R-MONTH: every grid is whole Monday-first weeks covering the month, 2020...2030")
    func allGrids() throws {
        var month = try #require(Month(year: 2020, month: 1))
        let end = try #require(Month(year: 2030, month: 12))
        while month <= end {
            let grid = month.grid
            #expect(grid.count.isMultiple(of: 7) && (28...42).contains(grid.count))
            #expect(grid.first?.day.weekday == .monday)
            #expect(grid.last?.day.weekday == .sunday)
            #expect(grid.filter { $0.isInMonth }.map(\.day) == month.days)
            #expect(grid.prefix(7).contains { $0.day == month.firstDay })
            month = month.next
        }
    }

    @Test("R-MONTH: navigation across year ends")
    func navigation() throws {
        let december = try #require(Month(year: 2026, month: 12))
        #expect(december.next == Month(year: 2027, month: 1))
        #expect(try #require(Month(year: 2027, month: 1)).previous == december)
        #expect(december.adding(months: 14) == Month(year: 2028, month: 2))
        #expect(december.adding(months: -12) == Month(year: 2025, month: 12))
        #expect(december.adding(months: -23) == Month(year: 2025, month: 1))
        #expect(december.adding(months: 0) == december)
        #expect(december.previous < december)
    }

    @Test("R-MONTH: month containing a day")
    func containing() {
        let month = Month(containing: day("2024-02-29"))
        #expect(month == Month(year: 2024, month: 2))
        #expect(month.contains(day("2024-02-01")))
        #expect(!month.contains(day("2024-03-01")))
        #expect(!month.contains(day("2023-02-15")))
    }
}
