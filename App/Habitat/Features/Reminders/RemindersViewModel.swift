import Foundation
import HabitatCore
import HabitatData
import Observation

/// One row of the reminders list.
struct ReminderRow: Identifiable, Equatable {
    let reminder: Reminder
    /// Label of a general reminder, habit name of a habit reminder.
    let title: String
    let timeText: String
    let daysText: String
    let accessibilityLabel: String

    var id: UUID { reminder.id }
}

/// A list section: "General" or one habit.
struct ReminderSection: Identifiable, Equatable {
    /// `general` or the habit's UUID.
    let id: String
    let title: String
    let rows: [ReminderRow]
}

/// Reminders screen state (R-REM): grouped rows, delete, permission banner.
@MainActor
@Observable
final class RemindersViewModel {
    private(set) var sections: [ReminderSection] = []
    private(set) var habits: [Habit] = []
    private(set) var reminderCount = 0
    var errorMessage: String?

    @ObservationIgnored let services: AppServices
    @ObservationIgnored let sync: ReminderSync

    init(services: AppServices, sync: ReminderSync) {
        self.services = services
        self.sync = sync
    }

    var isEmpty: Bool { reminderCount == 0 }

    var showsDeniedBanner: Bool { sync.authorization == .denied }

    var showsAllowButton: Bool { sync.authorization == .notDetermined }

    func load() {
        do {
            let reminders = try services.reminderRepository().all()
            habits = try services.habitRepository().all()
            reminderCount = reminders.count
            sections = Self.sections(reminders: reminders, habits: habits)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ reminder: Reminder) {
        errorMessage = nil
        do {
            try services.reminderRepository().delete(id: reminder.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        load()
        sync.replan()
    }

    /// After the editor saved: reload, re-plan, ask for permission the first time.
    func didSave() {
        load()
        sync.replan()
        Task { await sync.requestAuthorizationIfNeeded() }
    }

    func didDelete() {
        load()
        sync.replan()
    }

    func requestAuthorization() {
        Task { await sync.requestAuthorizationIfNeeded() }
    }

    // MARK: - Grouping

    static func sections(reminders: [Reminder], habits: [Habit]) -> [ReminderSection] {
        let general = reminders.filter { $0.kind.habitID == nil }
        var result: [ReminderSection] = []
        if !general.isEmpty {
            let rows = general.map { row($0, habits: habits) }
            result.append(ReminderSection(id: "general", title: "General", rows: rows))
        }
        let byHabit = Dictionary(grouping: reminders.filter { $0.kind.habitID != nil }) { $0.kind.habitID }
        // Habit order as stored (sort order), then reminders whose habit is gone.
        let knownIDs = habits.map(\.id)
        let orphanIDs = byHabit.keys.compactMap(\.self).filter { !knownIDs.contains($0) }
            .sorted { $0.uuidString < $1.uuidString }
        for habitID in knownIDs + orphanIDs {
            guard let items = byHabit[habitID], !items.isEmpty else { continue }
            result.append(ReminderSection(
                id: habitID.uuidString,
                title: habitTitle(habitID, habits: habits),
                rows: items.map { row($0, habits: habits) }
            ))
        }
        return result
    }

    static func row(_ reminder: Reminder, habits: [Habit]) -> ReminderRow {
        let title: String
        switch reminder.kind {
        case let .general(label): title = label
        case let .habit(id): title = habitTitle(id, habits: habits)
        }
        let timeText = ReminderFormat.time(reminder.time)
        let daysText = ReminderFormat.days(reminder.weekdays)
        let kindText = reminder.kind.habitID == nil ? "Reminder" : "Habit reminder"
        return ReminderRow(
            reminder: reminder,
            title: title,
            timeText: timeText,
            daysText: daysText,
            accessibilityLabel: "\(kindText): \(title), \(timeText), \(ReminderFormat.spokenDays(reminder.weekdays))"
        )
    }

    static func habitTitle(_ id: UUID, habits: [Habit]) -> String {
        guard let habit = habits.first(where: { $0.id == id }) else { return "Deleted habit" }
        return habit.archivedDay == nil ? habit.name : "\(habit.name) (archived)"
    }
}

/// Text for times and weekday sets.
enum ReminderFormat {
    /// Local short time (12- or 24-hour as the device is set).
    static func time(_ time: ReminderTime) -> String {
        guard let date = ReminderTimeConversion.date(from: time) else { return time.text }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func days(_ weekdays: Set<Weekday>) -> String {
        if let summary = summary(weekdays) { return summary }
        return weekdays.sorted().map(\.shortName).joined(separator: ", ")
    }

    static func spokenDays(_ weekdays: Set<Weekday>) -> String {
        if let summary = summary(weekdays) { return summary }
        return weekdays.sorted().map(fullName).joined(separator: ", ")
    }

    static func fullName(_ day: Weekday) -> String {
        switch day {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    private static func summary(_ weekdays: Set<Weekday>) -> String? {
        let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekend: Set<Weekday> = [.saturday, .sunday]
        if weekdays.count == Weekday.allCases.count { return "Every day" }
        if weekdays == workdays { return "Weekdays" }
        if weekdays == weekend { return "Weekends" }
        return nil
    }
}

/// `ReminderTime` and the `Date` a `DatePicker` edits (today at that time, device calendar).
enum ReminderTimeConversion {
    static func date(from time: ReminderTime) -> Date? {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())
    }

    static func time(from date: Date) -> ReminderTime? {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ReminderTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
