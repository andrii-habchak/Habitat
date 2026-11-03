/// The five top-level tabs, in tab bar order.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case habits
    case week
    case month
    case reminders
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .habits: "Habits"
        case .week: "Week"
        case .month: "Month"
        case .reminders: "Reminders"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .habits: "checklist"
        case .week: "calendar.day.timeline.left"
        case .month: "calendar"
        case .reminders: "bell"
        case .settings: "gearshape"
        }
    }
}
