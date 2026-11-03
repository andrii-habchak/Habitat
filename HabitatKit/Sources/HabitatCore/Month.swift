/// A calendar month and its Monday-first grid (R-MONTH).
public struct Month: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int

    /// `nil` for a month outside 1...12 or a year outside `DayKey.yearRange`.
    public init?(year: Int, month: Int) {
        guard DayKey.yearRange.contains(year), (1...12).contains(month) else { return nil }
        self.year = year
        self.month = month
    }

    /// The month that contains `day`.
    public init(containing day: DayKey) {
        year = day.year
        month = day.month
    }

    public var numberOfDays: Int { DayKey.daysInMonth(year: year, month: month) }

    public var firstDay: DayKey { DayKey(year: year, month: month, day: 1) ?? DayKey(serial: 0) }
    public var lastDay: DayKey { firstDay.adding(days: numberOfDays - 1) }

    /// 1st ... last day of the month.
    public var days: [DayKey] { (0..<numberOfDays).map { firstDay.adding(days: $0) } }

    public var previous: Month { Month(containing: firstDay.adding(days: -1)) }
    public var next: Month { Month(containing: lastDay.adding(days: 1)) }

    /// The month `count` months later (earlier when negative).
    public func adding(months count: Int) -> Month {
        let index = year * 12 + (month - 1) + count
        return Month(year: index / 12, month: index % 12 + 1) ?? self
    }

    public func contains(_ day: DayKey) -> Bool {
        day.year == year && day.month == month
    }

    /// Whole weeks Monday-first covering the month: leading days from the previous month,
    /// the month itself, trailing days from the next one. 4 to 6 rows of 7 cells.
    public var grid: [MonthGridCell] {
        let first = Week(containing: firstDay).start
        let last = Week(containing: lastDay).end
        return (0...first.days(to: last)).map { offset in
            let day = first.adding(days: offset)
            return MonthGridCell(day: day, isInMonth: contains(day))
        }
    }

    public static func < (lhs: Month, rhs: Month) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// One cell of the month grid.
public struct MonthGridCell: Hashable, Sendable {
    public let day: DayKey
    /// `false` for leading and trailing days of the neighbouring months.
    public let isInMonth: Bool

    public init(day: DayKey, isInMonth: Bool) {
        self.day = day
        self.isInMonth = isInMonth
    }
}
