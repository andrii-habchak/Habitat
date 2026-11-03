import Foundation

/// How often a habit should be done (PLAN §2).
public enum Goal: Hashable, Sendable {
    /// Every day (7 per week).
    case daily
    /// `N` days per week, `N` in `Goal.weeklyRange`. Build it with `Goal.weekly(_:)` to validate.
    case timesPerWeek(Int)

    public static let weeklyRange = 1...7

    /// A validated `timesPerWeek(count)`.
    public static func weekly(_ count: Int) throws(GoalError) -> Goal {
        let goal = Goal.timesPerWeek(count)
        try goal.validate()
        return goal
    }

    public func validate() throws(GoalError) {
        if case let .timesPerWeek(count) = self, !Self.weeklyRange.contains(count) {
            throw .timesPerWeekOutOfRange(count)
        }
    }

    /// `N`: the number of days per week that meets the goal.
    public var weeklyTarget: Int {
        switch self {
        case .daily: 7
        case let .timesPerWeek(count): count
        }
    }
}

public enum GoalError: Error, Equatable, Sendable, CustomStringConvertible {
    case timesPerWeekOutOfRange(Int)

    public var description: String {
        switch self {
        case let .timesPerWeekOutOfRange(count):
            "A weekly goal must be between 1 and 7 days, not \(count)."
        }
    }
}

extension Goal: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, count
    }

    private enum Kind: String, Codable {
        case daily, timesPerWeek
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .daily:
            self = .daily
        case .timesPerWeek:
            let count = try container.decode(Int.self, forKey: .count)
            do {
                self = try Goal.weekly(count)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: .count, in: container, debugDescription: error.description
                )
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(Kind.daily, forKey: .kind)
        case let .timesPerWeek(count):
            try container.encode(Kind.timesPerWeek, forKey: .kind)
            try container.encode(count, forKey: .count)
        }
    }
}

extension GoalError: LocalizedError {
    /// Same text as `description`, so `localizedDescription` and alerts show it.
    public var errorDescription: String? { description }
}
