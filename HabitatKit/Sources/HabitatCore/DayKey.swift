/// A calendar day in the proleptic Gregorian calendar, with no time of day (PLAN §2).
///
/// Stored as the number of days since 1970-01-01, so arithmetic and comparison never pass
/// through `Date`, time zones or DST. Text and JSON form is `yyyy-MM-dd`.
///
/// Supported years are 0001...9999 (`yearRange`): parsing and `init(year:month:day:)` reject
/// anything else. `adding(days:)` and `init(serial:)` do not check the range; a result outside
/// it is out of contract (its `text` is no longer a four-digit `yyyy`).
public struct DayKey: Hashable, Comparable, Sendable {
    /// Days since 1970-01-01 (negative before it).
    public let serial: Int

    /// Supported years: four-digit `yyyy`.
    public static let yearRange = 1...9999

    public init(serial: Int) {
        self.serial = serial
    }

    /// A real calendar day, or `nil` for an impossible one (`2026-02-30`, month 13, year 0).
    public init?(year: Int, month: Int, day: Int) {
        guard Self.yearRange.contains(year), (1...12).contains(month),
              (1...Self.daysInMonth(year: year, month: month)).contains(day)
        else { return nil }
        serial = Self.serial(year: year, month: month, day: day)
    }

    /// Parses exactly `yyyy-MM-dd`; anything else gives `nil`.
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var year: Int { civil.year }
    public var month: Int { civil.month }
    public var day: Int { civil.day }

    /// Day of the week, Monday first (independent of locale).
    public var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        let offset = ((serial % 7) + 7 + 3) % 7
        return Weekday.allCases[offset]
    }

    /// The day `days` later (earlier when negative). Out of contract outside `yearRange`.
    public func adding(days: Int) -> DayKey {
        DayKey(serial: serial + days)
    }

    /// Whole days from `self` to `other` (positive when `other` is later).
    public func days(to other: DayKey) -> Int {
        other.serial - serial
    }

    /// `yyyy-MM-dd`.
    public var text: String {
        let parts = civil
        return Self.pad(parts.year, 4) + "-" + Self.pad(parts.month, 2) + "-" + Self.pad(parts.day, 2)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.serial < rhs.serial
    }

    // MARK: Calendar rules

    public static func isLeapYear(_ year: Int) -> Bool {
        (year.isMultiple(of: 4) && !year.isMultiple(of: 100)) || year.isMultiple(of: 400)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    // Days-from-civil and civil-from-days, after H. Hinnant's public-domain algorithms.
    private static func serial(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private var civil: Civil {
        let shifted = serial + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return Civil(year: year, month: month, day: day)
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

private struct Civil {
    let year: Int
    let month: Int
    let day: Int
}

extension DayKey: CustomStringConvertible {
    public var description: String { text }
}

extension DayKey: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = DayKey(text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "\"\(text)\" is not a calendar day (yyyy-MM-dd)"
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// Day of the week, Monday first (`firstWeekday = 2` in Foundation terms, fixed).
public enum Weekday: Int, CaseIterable, Codable, Comparable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// Short English name, used in messages (`Mon`).
    public var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
