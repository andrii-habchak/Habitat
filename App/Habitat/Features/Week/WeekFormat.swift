import HabitatCore

/// Text for days and weeks. English, locale independent, built from `DayKey` (no `Date`).
enum WeekFormat {
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    private static let weekdayNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]

    static func monthName(_ day: DayKey) -> String { monthNames[day.month - 1] }

    static func weekdayName(_ day: DayKey) -> String { weekdayNames[day.weekday.rawValue - 1] }

    /// "M", "T", ... for the column header.
    static func weekdayLetter(_ day: DayKey) -> String { String(weekdayName(day).prefix(1)) }

    /// "Mon", "Tue", ...
    static func weekdayShort(_ day: DayKey) -> String { String(weekdayName(day).prefix(3)) }

    /// "Monday 2 November".
    static func spokenDay(_ day: DayKey) -> String {
        "\(weekdayName(day)) \(day.day) \(monthName(day))"
    }

    /// "2 - 8 Nov 2026", "28 Dec - 3 Jan 2027".
    static func rangeTitle(_ week: Week) -> String {
        let first = week.start
        let last = week.end
        let shortFirst = String(monthName(first).prefix(3))
        let shortLast = String(monthName(last).prefix(3))
        if first.month == last.month {
            return "\(first.day) \u{2013} \(last.day) \(shortLast) \(last.year)"
        }
        if first.year == last.year {
            return "\(first.day) \(shortFirst) \u{2013} \(last.day) \(shortLast) \(last.year)"
        }
        return "\(first.day) \(shortFirst) \(first.year) \u{2013} \(last.day) \(shortLast) \(last.year)"
    }

    /// "this week", "last week", "N weeks ago" for a week `offset` weeks from the current one.
    static func spokenWeek(offset: Int) -> String {
        switch offset {
        case 0: "this week"
        case -1: "last week"
        default: "\(-offset) weeks ago"
        }
    }

    static func streakText(_ count: Int, weekly: Bool) -> String {
        let unit = weekly ? "week" : "day"
        return "\(count) \(unit)\(count == 1 ? "" : "s")"
    }
}
