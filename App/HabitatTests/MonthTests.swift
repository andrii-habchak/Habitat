import Foundation
import HabitatCore
import Testing
@testable import Habitat

/// R-MONTH: donut geometry and the month grid cells.
@Suite("DonutGeometry (R-MONTH)")
struct DonutGeometryTests {
    @Test("no segments, no arcs")
    func none() {
        #expect(DonutGeometry.arcs(count: 0).isEmpty)
        #expect(DonutGeometry.arcs(count: -1).isEmpty)
    }

    @Test("one segment is a full ring without a gap")
    func single() {
        #expect(DonutGeometry.arcs(count: 1) == [DonutArc(start: 0, end: 1)])
    }

    @Test("several segments are equal, ordered and separated by the gap")
    func several() {
        let arcs = DonutGeometry.arcs(count: 4)
        #expect(arcs.count == 4)
        let lengths = arcs.map { $0.end - $0.start }
        for length in lengths { #expect(abs(length - (0.25 - DonutGeometry.gapFraction)) < 1e-9) }
        for index in 1..<arcs.count {
            #expect(abs((arcs[index].start - arcs[index - 1].end) - DonutGeometry.gapFraction) < 1e-9)
        }
        #expect(arcs.first!.start > 0)
        #expect(arcs.last!.end < 1)
    }

    @Test("with many segments the gap is capped at half a slot")
    func largeCount() {
        let arcs = DonutGeometry.arcs(count: 30)
        let slot = 1.0 / 30
        #expect(arcs.count == 30)
        for arc in arcs { #expect(abs((arc.end - arc.start) - slot / 2) < 1e-9) }
        for index in 1..<arcs.count { #expect(arcs[index].start > arcs[index - 1].end) }
        #expect(arcs.first?.start ?? -1 >= 0)
        #expect(arcs.last?.end ?? 2 <= 1)
    }
}

@Suite("MonthCellBuilder (R-MONTH)")
struct MonthCellBuilderTests {
    private let november = Month(year: 2026, month: 11)!
    private let today = DayKey("2026-11-04")!

    private func day(_ text: String) -> DayKey { DayKey(text)! }

    private func habit(_ name: String, order: Int, created: String = "2026-10-01", archived: String? = nil) -> Habit {
        Habit(
            name: name, colorHex: "#3E63DD", goal: .daily, createdDay: day(created),
            archivedDay: archived.map(day), sortOrder: order
        )
    }

    @Test("grid is padded to 6 Monday-first rows")
    func paddedGrid() {
        let grid = MonthCellBuilder.paddedGrid(for: november)
        #expect(grid.count == 42)
        #expect(grid.first?.day == day("2026-10-26"))
        #expect(grid.first?.isInMonth == false)
        #expect(grid.filter(\.isInMonth).count == 30)
        #expect(grid[6].day == day("2026-11-01"))
        #expect(grid[6].isInMonth)
        #expect(grid.last?.day == day("2026-12-06"))
    }

    @Test("a habit counts only inside its lifetime")
    func lifetime() {
        let read = habit("Read", order: 0, created: "2026-11-03", archived: "2026-11-05")
        let cells = MonthCellBuilder.cells(month: november, habits: [read], done: [], filter: nil, today: today)
        let counts = Dictionary(uniqueKeysWithValues: cells.map { ($0.day.text, $0.activeCount) })
        #expect(counts["2026-11-02"] == 0)
        #expect(counts["2026-11-03"] == 1)
        #expect(counts["2026-11-05"] == 1)
        #expect(counts["2026-11-06"] == 0)
    }

    @Test("done segments, value text and sort order")
    func segments() throws {
        let first = habit("A", order: 0)
        let second = habit("B", order: 1)
        let done: Set<DoneKey> = [DoneKey(habitID: second.id, day: day("2026-11-02"))]
        let cells = MonthCellBuilder.cells(
            month: november, habits: [second, first], done: done, filter: nil, today: today
        )
        let cell = try #require(cells.first { $0.day == day("2026-11-02") })
        #expect(cell.segments.map(\.habitID) == [first.id, second.id])
        #expect(cell.segments.map(\.isDone) == [false, true])
        #expect(cell.valueText == "1/2")
    }

    @Test("the filter limits the donut to one habit (single ring)")
    func filter() throws {
        let first = habit("A", order: 0)
        let second = habit("B", order: 1)
        let cells = MonthCellBuilder.cells(
            month: november, habits: [first, second], done: [], filter: second.id, today: today
        )
        let cell = try #require(cells.first { $0.day == day("2026-11-02") })
        #expect(cell.segments.map(\.habitID) == [second.id])
    }

    @Test("today, future and out-of-month flags")
    func flags() throws {
        let cells = MonthCellBuilder.cells(month: november, habits: [], done: [], filter: nil, today: today)
        let todayCell = try #require(cells.first { $0.day == today })
        #expect(todayCell.isToday)
        #expect(!todayCell.isFuture)
        let future = try #require(cells.first { $0.day == day("2026-11-05") })
        #expect(future.isFuture)
        let leading = try #require(cells.first)
        #expect(!leading.isInMonth)
    }
}

/// R-MONTH, R-A11Y: month and weekday names are resolved (regression: "M11 2026").
@Suite("MonthSymbols (R-MONTH, R-A11Y)")
struct MonthSymbolsTests {
    private let english = Locale(identifier: "en_US")

    @Test("title names the month and year")
    func title() throws {
        let november = try #require(Month(year: 2026, month: 11))
        #expect(MonthSymbols.title(november, locale: english) == "November 2026")
    }

    @Test("day names use the full weekday and month")
    func dayName() throws {
        let monday = try #require(DayKey("2026-10-26"))
        let sunday = try #require(DayKey("2026-11-01"))
        #expect(MonthSymbols.dayName(monday, locale: english) == "Monday 26 October")
        #expect(MonthSymbols.dayName(sunday, locale: english) == "Sunday 1 November")
    }

    @Test("weekday headers are Monday first")
    func headers() {
        let long = Weekday.allCases.map { MonthSymbols.header($0, compact: false, locale: english) }
        #expect(long == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        let short = Weekday.allCases.map { MonthSymbols.header($0, compact: true, locale: english) }
        #expect(short == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test("names follow the locale")
    func otherLocale() {
        #expect(MonthSymbols.monthName(11, locale: english) == "November")
        #expect(MonthSymbols.monthName(11, locale: Locale(identifier: "fr_FR")) == "novembre")
        #expect(MonthSymbols.monthName(1, locale: english) == "January")
    }
}
