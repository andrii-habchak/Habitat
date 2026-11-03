import HabitatCore
import HabitatData
import Observation
import SwiftUI

/// One day cell of a habit row.
struct WeekCell: Identifiable, Hashable {
    let day: DayKey
    let isDone: Bool
    /// False for future days and days outside the habit's lifetime.
    let isEnabled: Bool
    var id: DayKey { day }
}

/// One habit's row in a week: cells, weekly progress (weekly goals only) and streak.
struct HabitWeekRow: Identifiable, Hashable {
    let habit: Habit
    let cells: [WeekCell]
    let progress: WeeklyProgress?
    /// Streak as of today (R-STREAK), whichever week is shown.
    let streak: Int
    var id: UUID { habit.id }

    var isWeekly: Bool { progress != nil }

    /// Pure builder, used by the view model.
    static func make(habit: Habit, week: Week, doneDays: Set<DayKey>, today: DayKey) -> HabitWeekRow {
        let cells = week.days.map { day in
            WeekCell(
                day: day,
                isDone: doneDays.contains(day) && habit.isActive(on: day),
                isEnabled: day <= today && habit.isActive(on: day)
            )
        }
        let progress: WeeklyProgress? = if case .timesPerWeek = habit.goal {
            WeeklyProgress(week: week, goal: habit.goal, doneDays: doneDays, today: today)
        } else {
            nil
        }
        return HabitWeekRow(
            habit: habit,
            cells: cells,
            progress: progress,
            streak: habit.streak(doneDays: doneDays, today: today)
        )
    }
}

extension WeeklyStatus {
    /// Value read by VoiceOver and UI tests.
    var spoken: String {
        switch self {
        case .met: "met"
        case .failed: "failed"
        case .inProgress: "in progress"
        }
    }
}

/// Loads and toggles the week grid. `revision` is bumped after every change so views re-read.
@MainActor
@Observable
final class WeekViewModel {
    /// 0 = the week of today, -1 = last week, ...
    var weekOffset = 0
    /// How many weeks back can be reached.
    static let maxWeeksBack = 104

    private(set) var revision = 0
    private(set) var errorMessage: String?

    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    var today: DayKey { services.today }

    var currentWeek: Week { Week(containing: today) }

    func week(offset: Int) -> Week { currentWeek.adding(weeks: offset) }

    var canGoPrevious: Bool { weekOffset > -Self.maxWeeksBack }
    var canGoNext: Bool { weekOffset < 0 }

    func goPrevious() { if canGoPrevious { weekOffset -= 1 } }
    func goNext() { if canGoNext { weekOffset += 1 } }

    func refresh() { revision += 1 }

    /// Rows for `week`: habits whose lifetime touches the week, in list order.
    func rows(for week: Week) -> [HabitWeekRow] {
        _ = revision
        do {
            let completions = services.completionRepository()
            return try services.habitRepository().all()
                .filter { $0.createdDay <= week.end && ($0.archivedDay.map { $0 >= week.start } ?? true) }
                .map { habit in
                    HabitWeekRow.make(
                        habit: habit,
                        week: week,
                        doneDays: try completions.doneDays(habitID: habit.id),
                        today: today
                    )
                }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func toggle(habitID: UUID, day: DayKey) {
        do {
            try services.completionRepository().toggle(habitID: habitID, day: day)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
