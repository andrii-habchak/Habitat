import Foundation

/// A local time of day, minute precision.
public struct ReminderTime: Hashable, Comparable, Codable, Sendable {
    public let hour: Int
    public let minute: Int

    /// `nil` outside 00:00...23:59.
    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var minuteOfDay: Int { hour * 60 + minute }

    /// `HH:mm`.
    public var text: String {
        (hour < 10 ? "0" : "") + String(hour) + ":" + (minute < 10 ? "0" : "") + String(minute)
    }

    public static func < (lhs: ReminderTime, rhs: ReminderTime) -> Bool {
        lhs.minuteOfDay < rhs.minuteOfDay
    }

    private enum CodingKeys: String, CodingKey { case hour, minute }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)
        guard let time = ReminderTime(hour: hour, minute: minute) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "\(hour):\(minute) is not a time of day (00:00...23:59)"
            ))
        }
        self = time
    }
}

/// What a reminder is about (PLAN §2).
public enum ReminderKind: Hashable, Sendable {
    /// A free reminder with its own label.
    case general(label: String)
    /// A reminder for one habit.
    case habit(UUID)

    /// The habit this reminder targets, if any.
    public var habitID: UUID? {
        if case let .habit(id) = self { return id }
        return nil
    }
}

extension ReminderKind: Codable {
    private enum CodingKeys: String, CodingKey { case type, label, habitID }
    private enum KindType: String, Codable { case general, habit }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(KindType.self, forKey: .type) {
        case .general: self = .general(label: try container.decode(String.self, forKey: .label))
        case .habit: self = .habit(try container.decode(UUID.self, forKey: .habitID))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .general(label):
            try container.encode(KindType.general, forKey: .type)
            try container.encode(label, forKey: .label)
        case let .habit(id):
            try container.encode(KindType.habit, forKey: .type)
            try container.encode(id, forKey: .habitID)
        }
    }
}

/// A repeating reminder: a kind, a time and the weekdays it fires on (R-REM).
public struct Reminder: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: ReminderKind
    public var time: ReminderTime
    public var weekdays: Set<Weekday>

    public init(id: UUID = UUID(), kind: ReminderKind, time: ReminderTime, weekdays: Set<Weekday>) {
        self.id = id
        self.kind = kind
        self.time = time
        self.weekdays = weekdays
    }

    /// Duplicate rule (PLAN §2): same kind, same target, same time, overlapping weekdays.
    /// General reminders have no target, so any two general reminders can clash; the label
    /// does not tell them apart.
    public func clashes(with other: Reminder) -> Bool {
        guard id != other.id, time == other.time, !weekdays.isDisjoint(with: other.weekdays) else {
            return false
        }
        switch (kind, other.kind) {
        case (.general, .general): return true
        case let (.habit(lhs), .habit(rhs)): return lhs == rhs
        default: return false
        }
    }

    /// Checks the reminder alone and against `existing` (the reminder itself, same id, is
    /// skipped so an edit does not clash with its old version).
    ///
    /// - Parameter habitName: name of a habit, for the clash message.
    public func validate(
        against existing: [Reminder],
        habitName: (UUID) -> String? = { _ in nil }
    ) throws(ReminderError) {
        if weekdays.isEmpty { throw .noWeekdays }
        if case let .general(label) = kind, label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw .emptyLabel
        }
        if let clash = existing.first(where: clashes(with:)) {
            throw .duplicate(of: clash.id, message: Self.clashMessage(for: clash, habitName: habitName))
        }
    }

    /// Weekdays as `Mon, Wed, Fri`, Monday first.
    public var weekdaysText: String {
        weekdays.sorted().map(\.shortName).joined(separator: ", ")
    }

    private static func clashMessage(for clash: Reminder, habitName: (UUID) -> String?) -> String {
        let subject: String
        switch clash.kind {
        case let .general(label):
            subject = "the reminder \"\(label)\""
        case let .habit(id):
            subject = habitName(id).map { "the reminder for \"\($0)\"" } ?? "a reminder for this habit"
        }
        return "Clashes with \(subject) at \(clash.time.text) on \(clash.weekdaysText)."
    }
}

extension Reminder: Codable {
    private enum CodingKeys: String, CodingKey { case id, kind, time, weekdays }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ReminderKind.self, forKey: .kind)
        time = try container.decode(ReminderTime.self, forKey: .time)
        weekdays = Set(try container.decode([Weekday].self, forKey: .weekdays))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(time, forKey: .time)
        try container.encode(weekdays.sorted(), forKey: .weekdays)
    }
}

public enum ReminderError: Error, Equatable, Sendable, CustomStringConvertible {
    case noWeekdays
    case emptyLabel
    /// Clashes with the reminder `of`; `message` names it.
    case duplicate(of: UUID, message: String)

    public var description: String {
        switch self {
        case .noWeekdays: "Pick at least one weekday."
        case .emptyLabel: "A general reminder needs a label."
        case let .duplicate(_, message): message
        }
    }
}
