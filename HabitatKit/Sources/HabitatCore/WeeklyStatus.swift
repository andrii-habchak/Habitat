/// Status of a habit's weekly goal (PLAN §2, D5).
public enum WeeklyStatus: String, Hashable, Sendable {
    /// Green: `c >= N`.
    case met
    /// Red: `c < N` and `c + r < N` (unreachable, or the week is over).
    case failed
    /// Neutral/amber: `c < N` and `c + r >= N`.
    case inProgress

    /// - Parameters:
    ///   - done: `c`, days done in the week.
    ///   - target: `N`.
    ///   - daysLeft: `r`, days left including today (0 for a finished week).
    public static func evaluate(done: Int, target: Int, daysLeft: Int) -> WeeklyStatus {
        if done >= target { return .met }
        if done + daysLeft < target { return .failed }
        return .inProgress
    }
}

/// `c/N` and the status of one habit in one week.
public struct WeeklyProgress: Hashable, Sendable {
    public let week: Week
    /// `c`.
    public let done: Int
    /// `N`.
    public let target: Int
    /// `r`.
    public let daysLeft: Int

    public var status: WeeklyStatus {
        WeeklyStatus.evaluate(done: done, target: target, daysLeft: daysLeft)
    }

    /// Counts the days of `week` found in `doneDays`, as seen on `today`.
    public init(week: Week, goal: Goal, doneDays: Set<DayKey>, today: DayKey) {
        self.week = week
        target = goal.weeklyTarget
        done = week.days.filter(doneDays.contains).count
        daysLeft = week.daysLeft(today: today)
    }
}
