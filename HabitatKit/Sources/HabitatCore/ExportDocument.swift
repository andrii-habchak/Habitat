import Foundation

/// The JSON export file (PLAN §2, R-DATA): `schema`, habits, completions, reminders.
public struct ExportDocument: Hashable, Codable, Sendable {
    public var schema: Int
    public var habits: [Habit]
    public var completions: [Completion]
    public var reminders: [Reminder]

    public init(
        habits: [Habit] = [],
        completions: [Completion] = [],
        reminders: [Reminder] = [],
        schema: Int = HabitatCore.exportSchemaVersion
    ) {
        self.schema = schema
        self.habits = habits
        self.completions = completions
        self.reminders = reminders
    }
}

/// Encodes and validates export files. Decoding either returns a document that passes
/// every rule or throws an `ImportError` with a readable message; it never returns a
/// partial document.
public enum ExportCodec {
    public static func encode(_ document: ExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws(ImportError) -> ExportDocument {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw .notJSON
        }
        guard let root = object as? [String: Any] else { throw .notAnObject }
        guard let rawSchema = root["schema"] else { throw .missingSchema }
        guard let number = rawSchema as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let schema = Int(exactly: number.doubleValue)
        else { throw .invalidSchema }
        guard schema == HabitatCore.exportSchemaVersion else { throw .unsupportedSchema(schema) }

        let document: ExportDocument
        do {
            document = try JSONDecoder().decode(ExportDocument.self, from: data)
        } catch let error as DecodingError {
            throw ImportError(error)
        } catch {
            throw .malformed(path: "", reason: String(describing: error))
        }
        try validate(document)
        return document
    }

    /// Cross-record rules: valid habits, unique ids, no dangling references, no duplicates.
    public static func validate(_ document: ExportDocument) throws(ImportError) {
        var habitIDs = Set<UUID>()
        for (index, habit) in document.habits.enumerated() {
            do { try habit.validate() } catch { throw .invalidHabit(index: index, reason: error.description) }
            guard habitIDs.insert(habit.id).inserted else {
                throw .duplicateID(path: "habits[\(index)]", id: habit.id)
            }
        }
        var completions = Set<Completion>()
        for (index, completion) in document.completions.enumerated() {
            guard habitIDs.contains(completion.habitID) else {
                throw .unknownHabit(path: "completions[\(index)]", id: completion.habitID)
            }
            guard completions.insert(completion).inserted else {
                throw .duplicateCompletion(index: index)
            }
        }
        var reminderIDs = Set<UUID>()
        for (index, reminder) in document.reminders.enumerated() {
            if let habitID = reminder.kind.habitID, !habitIDs.contains(habitID) {
                throw .unknownHabit(path: "reminders[\(index)]", id: habitID)
            }
            guard reminderIDs.insert(reminder.id).inserted else {
                throw .duplicateID(path: "reminders[\(index)]", id: reminder.id)
            }
            do {
                try reminder.validate(against: Array(document.reminders[..<index])) { id in
                    document.habits.first { $0.id == id }?.name
                }
            } catch {
                throw .invalidReminder(index: index, reason: error.description)
            }
        }
    }
}

/// Why an import file was refused (R-DATA: readable, nothing changes).
public enum ImportError: Error, Equatable, Sendable, CustomStringConvertible {
    case notJSON
    case notAnObject
    case missingSchema
    case invalidSchema
    case unsupportedSchema(Int)
    /// A field is missing, has the wrong type or an invalid value. `path` like `habits[0].goal`.
    case malformed(path: String, reason: String)
    case invalidHabit(index: Int, reason: String)
    case invalidReminder(index: Int, reason: String)
    case duplicateID(path: String, id: UUID)
    case duplicateCompletion(index: Int)
    case unknownHabit(path: String, id: UUID)

    public var description: String {
        switch self {
        case .notJSON:
            "The file is not valid JSON."
        case .notAnObject:
            "The file is not a Habitat export (expected a JSON object)."
        case .missingSchema:
            "The file is not a Habitat export (no \"schema\" field)."
        case .invalidSchema:
            "The \"schema\" field must be a whole number."
        case let .unsupportedSchema(version):
            "Schema \(version) is not supported (this version reads schema \(HabitatCore.exportSchemaVersion))."
        case let .malformed(path, reason):
            path.isEmpty ? "The file is malformed: \(reason)" : "The file is malformed at \(path): \(reason)"
        case let .invalidHabit(index, reason):
            "Habit \(index + 1) is invalid: \(reason)"
        case let .invalidReminder(index, reason):
            "Reminder \(index + 1) is invalid: \(reason)"
        case let .duplicateID(path, id):
            "\(path) repeats the id \(id.uuidString)."
        case let .duplicateCompletion(index):
            "Completion \(index + 1) appears twice."
        case let .unknownHabit(path, id):
            "\(path) refers to a habit that is not in the file (\(id.uuidString))."
        }
    }

    init(_ error: DecodingError) {
        switch error {
        case let .keyNotFound(key, context):
            self = .malformed(path: Self.path(context.codingPath), reason: "missing field \"\(key.stringValue)\"")
        case let .valueNotFound(type, context):
            self = .malformed(path: Self.path(context.codingPath), reason: "missing value (expected \(type))")
        case let .typeMismatch(type, context):
            self = .malformed(path: Self.path(context.codingPath), reason: "wrong type (expected \(type))")
        case let .dataCorrupted(context):
            self = .malformed(path: Self.path(context.codingPath), reason: context.debugDescription)
        @unknown default:
            self = .malformed(path: "", reason: String(describing: error))
        }
    }

    static func path(_ codingPath: [any CodingKey]) -> String {
        codingPath.reduce(into: "") { text, key in
            if let index = key.intValue {
                text += "[\(index)]"
            } else {
                text += (text.isEmpty ? "" : ".") + key.stringValue
            }
        }
    }
}

extension ImportError: LocalizedError {
    /// Same text as `description`, so `localizedDescription` and alerts show it.
    public var errorDescription: String? { description }
}
