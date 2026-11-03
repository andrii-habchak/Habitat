import Foundation

/// A local wall-clock moment: the calendar day and the minute of that day.
public struct LocalMoment: Hashable, Sendable {
    public var day: DayKey
    /// Minutes since local midnight, 0...1439.
    public var minuteOfDay: Int

    public init(day: DayKey, minuteOfDay: Int = 0) {
        self.day = day
        self.minuteOfDay = min(max(minuteOfDay, 0), 24 * 60 - 1)
    }

    /// The local day and minute of `date` in `timeZone` (Gregorian, so DST only moves the
    /// minute, never the day it falls on).
    public init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = parts.year ?? 1970
        let month = parts.month ?? 1
        let dayOfMonth = parts.day ?? 1
        let day = DayKey(year: year, month: month, day: dayOfMonth) ?? DayKey(serial: 0)
        self.init(day: day, minuteOfDay: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }
}

/// Injected source of "now" (PLAN §3), so rules never read the real date directly.
public protocol Clock: Sendable {
    func now() -> LocalMoment
}

extension Clock {
    /// The current calendar day.
    public var today: DayKey { now().day }
}

/// The device clock in a given time zone (the current one by default).
public struct SystemClock: Clock {
    public var timeZone: TimeZone

    public init(timeZone: TimeZone = .autoupdatingCurrent) {
        self.timeZone = timeZone
    }

    public func now() -> LocalMoment {
        LocalMoment(date: Date(), timeZone: timeZone)
    }
}

/// A clock pinned to one moment, for tests and `-today`.
public struct FixedClock: Clock {
    public var moment: LocalMoment

    public init(_ moment: LocalMoment) {
        self.moment = moment
    }

    public init(day: DayKey, minuteOfDay: Int = 0) {
        self.init(LocalMoment(day: day, minuteOfDay: minuteOfDay))
    }

    public func now() -> LocalMoment { moment }
}
