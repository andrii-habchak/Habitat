import Foundation
import HabitatCore

/// Display text for goals and streaks (list rows and the editor).
enum HabitFormat {
    static func goalText(_ goal: Goal) -> String {
        switch goal {
        case .daily:
            String(localized: "Every day")
        case let .timesPerWeek(count):
            if count == 1 { String(localized: "Once a week") } else { String(localized: "\(count) times a week") }
        }
    }

    /// Daily habits count days, weekly habits count weeks (R-STREAK).
    static func streakText(_ streak: Int, goal: Goal) -> String {
        guard streak > 0 else { return String(localized: "No streak") }
        switch goal {
        case .daily:
            return streak == 1 ? String(localized: "1 day streak") : String(localized: "\(streak) day streak")
        case .timesPerWeek:
            return streak == 1 ? String(localized: "1 week streak") : String(localized: "\(streak) week streak")
        }
    }

    /// VoiceOver label: name, goal and streak.
    static func accessibilityLabel(name: String, goal: Goal, streak: Int, archived: Bool) -> String {
        var parts = [name, goalText(goal), streakText(streak, goal: goal)]
        if archived { parts.append(String(localized: "Archived")) }
        return parts.joined(separator: ", ")
    }
}
