import Foundation
import HabitatCore

/// Why a repository call was refused. Rule violations of HabitatCore (`HabitError`,
/// `ReminderError`) are thrown as they are.
public enum RepositoryError: Error, Equatable, Sendable, CustomStringConvertible {
    case habitNotFound(UUID)
    case reminderNotFound(UUID)
    /// Completions cannot be set for a day after today.
    case futureDay(DayKey)
    /// The habit does not count on that day (before it was created or after it was archived).
    case habitNotActive(UUID, DayKey)

    public var description: String {
        switch self {
        case .habitNotFound:
            "That habit no longer exists."
        case .reminderNotFound:
            "That reminder no longer exists."
        case let .futureDay(day):
            "\(day) is in the future."
        case let .habitNotActive(_, day):
            "The habit does not count on \(day) (before it was created or after it was archived)."
        }
    }
}

extension RepositoryError: LocalizedError {
    public var errorDescription: String? { description }
}

/// Why a seed fixture could not be loaded.
public enum SeedError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownFixture(String)

    public var description: String {
        switch self {
        case let .unknownFixture(name):
            "Unknown seed fixture \"\(name)\" (known: \(SeedFixture.allCases.map(\.rawValue).joined(separator: ", ")))."
        }
    }
}

extension SeedError: LocalizedError {
    public var errorDescription: String? { description }
}
