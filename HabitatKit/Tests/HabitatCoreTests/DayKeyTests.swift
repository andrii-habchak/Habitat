import Foundation
@testable import HabitatCore
import Testing

@Suite("DayKey")
struct DayKeyTests {
    @Test("R-WEEK R-MONTH: text round trip and components", arguments: [
        "2026-11-03", "1970-01-01", "1969-12-31", "0001-01-01", "9999-12-31", "2024-02-29", "2000-02-29"
    ])
    func roundTrip(_ text: String) throws {
        let value = try #require(DayKey(text))
        #expect(value.text == text)
        #expect(value.description == text)
        #expect(DayKey(year: value.year, month: value.month, day: value.day) == value)
    }

    @Test("R-WEEK: malformed or impossible days are rejected", arguments: [
        "2026-02-30", "2025-02-29", "2100-02-29", "1900-02-29", "2026-13-01", "2026-00-10",
        "2026-04-31", "0000-01-01", "26-11-03", "2026-1-03", "2026/11/03", "2026-11-03T00:00",
        "abcd-ef-gh", "+026-11-03", ""
    ])
    func invalid(_ text: String) {
        #expect(DayKey(text) == nil)
    }

    @Test("R-MONTH: leap years follow the century rule", arguments: [
        (2024, true), (2026, false), (2000, true), (1900, false), (2100, false), (2400, true), (1600, true)
    ] as [(Int, Bool)])
    func leapYears(_ year: Int, _ leap: Bool) {
        #expect(DayKey.isLeapYear(year) == leap)
        #expect(DayKey.daysInMonth(year: year, month: 2) == (leap ? 29 : 28))
        #expect((DayKey(year: year, month: 2, day: 29) != nil) == leap)
    }

    @Test("R-WEEK: weekday of known days, Monday first", arguments: [
        ("1970-01-01", Weekday.thursday), ("2026-11-02", .monday), ("2026-11-03", .tuesday),
        ("2026-11-08", .sunday), ("2000-01-01", .saturday), ("0001-01-01", .monday),
        ("1969-12-31", .wednesday), ("1900-03-01", .thursday)
    ] as [(String, Weekday)])
    func weekday(_ text: String, _ expected: Weekday) {
        #expect(day(text).weekday == expected)
    }

    @Test("R-WEEK R-MONTH: adding days crosses month, year and leap-day ends")
    func addingDays() {
        #expect(day("2026-01-31").adding(days: 1) == day("2026-02-01"))
        #expect(day("2026-02-28").adding(days: 1) == day("2026-03-01"))
        #expect(day("2024-02-28").adding(days: 1) == day("2024-02-29"))
        #expect(day("2100-02-28").adding(days: 1) == day("2100-03-01"))
        #expect(day("2026-12-31").adding(days: 1) == day("2027-01-01"))
        #expect(day("2027-01-01").adding(days: -1) == day("2026-12-31"))
        #expect(day("2026-03-29").adding(days: 1) == day("2026-03-30"))
        #expect(day("2026-11-03").adding(days: 0) == day("2026-11-03"))
        #expect(day("2026-01-01").days(to: day("2027-01-01")) == 365)
        #expect(day("2024-01-01").days(to: day("2025-01-01")) == 366)
        #expect(day("2026-11-03").days(to: day("2026-11-01")) == -2)
    }

    @Test("R-WEEK: ordering follows the calendar")
    func ordering() {
        #expect(day("2026-11-02") < day("2026-11-03"))
        #expect(day("2025-12-31") < day("2026-01-01"))
        #expect(!(day("2026-11-03") < day("2026-11-03")))
        #expect([day("2026-12-01"), day("2026-01-05"), day("2026-06-30")].sorted()
                == [day("2026-01-05"), day("2026-06-30"), day("2026-12-01")])
    }

    @Test("R-WEEK R-MONTH: matches Foundation's Gregorian calendar for 1899...2101")
    func matchesFoundation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let start = try #require(calendar.date(from: DateComponents(year: 1899, month: 1, day: 1, hour: 12)))
        let first = day("1899-01-01")
        for offset in stride(from: 0, to: 74_000, by: 1) {
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: start))
            let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            let value = first.adding(days: offset)
            guard value.year == parts.year, value.month == parts.month, value.day == parts.day,
                  (value.weekday.rawValue % 7) + 1 == parts.weekday
            else {
                Issue.record("mismatch at \(value): \(parts)")
                return
            }
        }
    }

    @Test("R-DATA: Codable as a yyyy-MM-dd string")
    func codable() throws {
        let data = try JSONEncoder().encode([day("2026-11-03")])
        #expect(String(bytes: data, encoding: .utf8) == "[\"2026-11-03\"]")
        #expect(try JSONDecoder().decode([DayKey].self, from: data) == [day("2026-11-03")])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([DayKey].self, from: Data("[\"2026-02-30\"]".utf8))
        }
    }

    @Test("R-REM: weekday short names and order")
    func weekdayNames() {
        #expect(Weekday.allCases.map(\.shortName) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        #expect(Weekday.monday < Weekday.sunday)
    }
}

@Suite("Clock and local moments")
struct ClockTests {
    private func moment(_ iso: String, _ zone: String) throws -> LocalMoment {
        let date = try #require(ISO8601DateFormatter().date(from: iso))
        return LocalMoment(date: date, timeZone: try #require(TimeZone(identifier: zone)))
    }

    @Test("R-WEEK: Europe/Paris spring-forward night keeps the day", arguments: [
        ("2026-03-28T22:59:00Z", "2026-03-28", 23 * 60 + 59),
        ("2026-03-28T23:30:00Z", "2026-03-29", 30),
        ("2026-03-29T00:59:00Z", "2026-03-29", 60 + 59),
        ("2026-03-29T01:00:00Z", "2026-03-29", 3 * 60),
        ("2026-03-29T21:59:00Z", "2026-03-29", 23 * 60 + 59),
        ("2026-03-29T22:00:00Z", "2026-03-30", 0)
    // swiftlint:disable:next large_tuple
    ] as [(String, String, Int)])
    func parisMarch(_ iso: String, _ expectedDay: String, _ minute: Int) throws {
        let value = try moment(iso, "Europe/Paris")
        #expect(value.day == day(expectedDay))
        #expect(value.minuteOfDay == minute)
    }

    @Test("R-WEEK: Europe/Paris fall-back night keeps the day", arguments: [
        ("2026-10-24T21:59:00Z", "2026-10-24", 23 * 60 + 59),
        ("2026-10-24T22:00:00Z", "2026-10-25", 0),
        ("2026-10-25T00:30:00Z", "2026-10-25", 2 * 60 + 30),
        ("2026-10-25T01:30:00Z", "2026-10-25", 2 * 60 + 30),
        ("2026-10-25T22:59:00Z", "2026-10-25", 23 * 60 + 59),
        ("2026-10-25T23:00:00Z", "2026-10-26", 0)
    // swiftlint:disable:next large_tuple
    ] as [(String, String, Int)])
    func parisOctober(_ iso: String, _ expectedDay: String, _ minute: Int) throws {
        let value = try moment(iso, "Europe/Paris")
        #expect(value.day == day(expectedDay))
        #expect(value.minuteOfDay == minute)
    }

    @Test("R-WEEK: the same instant is a different day in different zones")
    func zones() throws {
        #expect(try moment("2026-11-02T23:30:00Z", "Europe/Paris").day == day("2026-11-03"))
        #expect(try moment("2026-11-02T23:30:00Z", "America/New_York").day == day("2026-11-02"))
    }

    @Test("R-WEEK: fixed clock pins today; minute is clamped to the day")
    func fixedClock() {
        let clock = FixedClock(day: day("2026-11-03"), minuteOfDay: 8 * 60)
        #expect(clock.today == day("2026-11-03"))
        #expect(clock.now().minuteOfDay == 480)
        #expect(LocalMoment(day: day("2026-11-03"), minuteOfDay: -5).minuteOfDay == 0)
        #expect(LocalMoment(day: day("2026-11-03"), minuteOfDay: 5000).minuteOfDay == 1439)
    }

    @Test("R-WEEK: the system clock reads the real local day")
    func systemClock() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let before = LocalMoment(date: Date(), timeZone: utc).day
        let today = SystemClock(timeZone: utc).today
        #expect(before.days(to: today) >= 0 && before.days(to: today) <= 1)
        #expect(SystemClock().timeZone == .autoupdatingCurrent)
    }
}
