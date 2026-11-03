/// A calendar week, Monday to Sunday, independent of the device locale (PLAN §2, D4).
public struct Week: Hashable, Comparable, Sendable {
    /// Foundation's numbering for the fixed first weekday (Monday).
    public static let firstWeekday = 2

    /// The Monday that starts the week.
    public let start: DayKey

    /// The week that contains `day`.
    public init(containing day: DayKey) {
        start = day.adding(days: -(day.weekday.rawValue - 1))
    }

    /// The Sunday that ends the week.
    public var end: DayKey { start.adding(days: 6) }

    /// Monday ... Sunday.
    public var days: [DayKey] { (0..<7).map { start.adding(days: $0) } }

    public var previous: Week { Week(containing: start.adding(days: -7)) }
    public var next: Week { Week(containing: start.adding(days: 7)) }

    /// The week `count` weeks later (earlier when negative).
    public func adding(weeks count: Int) -> Week {
        Week(containing: start.adding(days: 7 * count))
    }

    public func contains(_ day: DayKey) -> Bool {
        start <= day && day <= end
    }

    /// `r` in PLAN §2: days left including `today`. 7 for a week that has not started,
    /// 0 for a finished week.
    public func daysLeft(today: DayKey) -> Int {
        if today < start { return 7 }
        if today > end { return 0 }
        return today.days(to: end) + 1
    }

    public static func < (lhs: Week, rhs: Week) -> Bool {
        lhs.start < rhs.start
    }
}
