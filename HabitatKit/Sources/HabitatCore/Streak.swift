/// Streak rules (PLAN §2, R-STREAK).
///
/// Only days from `createdDay` through the reference day count. The reference day is
/// `today`, or the archive day for a habit archived before today, so an archived habit's
/// streak is frozen at its value on the archive day.
public enum Streak {
    public static func current(
        goal: Goal,
        doneDays: Set<DayKey>,
        createdDay: DayKey,
        archivedDay: DayKey? = nil,
        today: DayKey
    ) -> Int {
        switch goal {
        case .daily:
            daily(doneDays: doneDays, createdDay: createdDay, archivedDay: archivedDay, today: today)
        case .timesPerWeek:
            weekly(goal: goal, doneDays: doneDays, createdDay: createdDay, archivedDay: archivedDay, today: today)
        }
    }

    /// Consecutive done days up to the reference day; the reference day itself not yet done
    /// does not break the streak.
    public static func daily(
        doneDays: Set<DayKey>,
        createdDay: DayKey,
        archivedDay: DayKey? = nil,
        today: DayKey
    ) -> Int {
        let reference = referenceDay(archivedDay: archivedDay, today: today)
        var day = doneDays.contains(reference) ? reference : reference.adding(days: -1)
        var count = 0
        while day >= createdDay, doneDays.contains(day) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }

    /// Consecutive `met` weeks; the reference week counts once it is `met`, and an unmet
    /// reference week does not break the streak.
    public static func weekly(
        goal: Goal,
        doneDays: Set<DayKey>,
        createdDay: DayKey,
        archivedDay: DayKey? = nil,
        today: DayKey
    ) -> Int {
        let reference = referenceDay(archivedDay: archivedDay, today: today)
        guard reference >= createdDay else { return 0 }
        let counted = doneDays.filter { $0 >= createdDay && $0 <= reference }
        var week = Week(containing: reference)
        var count = 0
        if WeeklyProgress(week: week, goal: goal, doneDays: counted, today: reference).status == .met {
            count += 1
        }
        week = week.previous
        while week.end >= createdDay,
              WeeklyProgress(week: week, goal: goal, doneDays: counted, today: reference).status == .met {
            count += 1
            week = week.previous
        }
        return count
    }

    private static func referenceDay(archivedDay: DayKey?, today: DayKey) -> DayKey {
        if let archivedDay, archivedDay < today { return archivedDay }
        return today
    }
}
