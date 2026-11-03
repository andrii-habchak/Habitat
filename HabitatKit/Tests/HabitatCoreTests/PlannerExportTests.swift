import Foundation
import HabitatCore
import Testing

@Suite("Reminder planner")
struct ReminderPlannerTests {
    private let now = LocalMoment(day: day("2026-11-03"), minuteOfDay: 9 * 60)  // Tuesday 09:00
    private let everyDay = Set(Weekday.allCases)

    private func reminder(_ index: Int, _ kind: ReminderKind, at hour: Int, _ minute: Int = 0,
                          on weekdays: Set<Weekday>? = nil) -> Reminder {
        Reminder(id: uuid(100 + index), kind: kind, time: time(hour, minute), weekdays: weekdays ?? everyDay)
    }

    @Test("R-REM: rolling 14-day window including today, past times today skipped")
    func window() {
        let morning = reminder(1, .general(label: "Morning"), at: 9)   // 09:00 = now: skipped today
        let evening = reminder(2, .general(label: "Evening"), at: 21)
        let plan = ReminderPlanner.plan(reminders: [morning, evening], habits: [], completions: [], now: now)
        #expect(plan.count == 13 + 14)
        #expect(plan.first?.day == day("2026-11-03"))
        #expect(plan.first?.reminderID == evening.id)
        #expect(plan.last?.day == day("2026-11-16"))
        #expect(plan.allSatisfy { $0.day >= now.day && $0.day <= day("2026-11-16") })
        #expect(!plan.contains { $0.day == now.day && $0.reminderID == morning.id })
    }

    @Test("R-REM: only the reminder's weekdays are planned")
    func weekdays() {
        let weekend = reminder(1, .general(label: "Weekend"), at: 10, on: [.saturday, .sunday])
        let plan = ReminderPlanner.plan(reminders: [weekend], habits: [], completions: [], now: now)
        #expect(plan.map(\.day) == [day("2026-11-07"), day("2026-11-08"), day("2026-11-14"), day("2026-11-15")])
    }

    @Test("R-REM: never more than 60 requests, earliest kept")
    func cap() {
        let reminders = (0..<10).map { reminder($0, .general(label: "R\($0)"), at: 10 + $0 % 10, $0) }
        let plan = ReminderPlanner.plan(reminders: reminders, habits: [], completions: [], now: now)
        #expect(plan.count == 60)
        #expect(plan == plan.sorted { ($0.day, $0.time) < ($1.day, $1.time) })
        #expect(plan.last?.day == day("2026-11-08"))
        let full = ReminderPlanner.plan(reminders: reminders, habits: [], completions: [], now: now, maxRequests: 1000)
        #expect(full.count == 140)
        #expect(Array(full.prefix(60)) == plan)
        #expect(ReminderPlanner.maxRequests == 60)
        #expect(ReminderPlanner.windowDays == 14)
    }

    @Test("R-REM: a habit reminder is skipped on days the habit is already done")
    func doneDaySkip() {
        let read = habit(1, created: "2026-10-01")
        let rem = reminder(1, .habit(read.id), at: 20)
        let completions = [Completion(habitID: read.id, day: day("2026-11-03")),
                           Completion(habitID: read.id, day: day("2026-11-05")),
                           Completion(habitID: uuid(9), day: day("2026-11-04"))]
        let plan = ReminderPlanner.plan(reminders: [rem], habits: [read], completions: completions, now: now)
        #expect(plan.count == 12)
        #expect(!plan.contains { $0.day == day("2026-11-03") || $0.day == day("2026-11-05") })
        #expect(plan.contains { $0.day == day("2026-11-04") })
    }

    @Test("R-REM R-LIST: habit reminders follow the lifecycle and a missing habit plans nothing")
    func lifecycle() {
        let future = habit(1, created: "2026-11-10")
        let archived = habit(2, created: "2026-10-01", archived: "2026-11-05")
        let reminders = [reminder(1, .habit(future.id), at: 20), reminder(2, .habit(archived.id), at: 20),
                         reminder(3, .habit(uuid(99)), at: 20)]
        let plan = ReminderPlanner.plan(reminders: reminders, habits: [future, archived], completions: [], now: now)
        #expect(plan.filter { $0.reminderID == reminders[0].id }.map(\.day).first == day("2026-11-10"))
        #expect(plan.filter { $0.reminderID == reminders[0].id }.count == 7)
        #expect(plan.filter { $0.reminderID == reminders[1].id }.map(\.day)
                == [day("2026-11-03"), day("2026-11-04"), day("2026-11-05")])
        #expect(!plan.contains { $0.reminderID == reminders[2].id })
    }

    @Test("R-REM: identifiers are unique and stable")
    func identifiers() {
        let rem = reminder(1, .general(label: "Water"), at: 10)
        let plan = ReminderPlanner.plan(reminders: [rem], habits: [], completions: [], now: now)
        #expect(Set(plan.map(\.identifier)).count == plan.count)
        #expect(plan.first?.identifier == rem.id.uuidString + ".2026-11-03")
        #expect(plan.first?.kind == rem.kind)
        #expect(ReminderPlanner.plan(reminders: [rem], habits: [], completions: [], now: now) == plan)
    }

    @Test("R-REM: empty and degenerate inputs")
    func degenerate() {
        #expect(ReminderPlanner.plan(reminders: [], habits: [], completions: [], now: now).isEmpty)
        let rem = reminder(1, .general(label: "Water"), at: 10)
        #expect(ReminderPlanner.plan(reminders: [rem], habits: [], completions: [], now: now, windowDays: 0).isEmpty)
        #expect(ReminderPlanner.plan(reminders: [rem], habits: [], completions: [], now: now, maxRequests: -1).isEmpty)
    }
}

@Suite("Export schema")
struct ExportTests {
    private func sample() -> ExportDocument {
        let read = habit(1, goal: .timesPerWeek(3), created: "2026-10-01", name: "Read \"books\" — ünïcode")
        let walk = habit(2, created: "2026-09-15", archived: "2026-11-01", name: "Walk")
        return ExportDocument(
            habits: [read, walk],
            completions: [Completion(habitID: read.id, day: day("2026-11-02")),
                          Completion(habitID: walk.id, day: day("2024-02-29"))],
            reminders: [
                Reminder(
                    id: uuid(101), kind: .general(label: "Water"), time: time(8, 30), weekdays: [.monday, .friday]
                ),
                Reminder(id: uuid(102), kind: .habit(read.id), time: time(21, 0), weekdays: Set(Weekday.allCases))
            ]
        )
    }

    private func json(_ document: ExportDocument) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: ExportCodec.encode(document))
        return try #require(object as? [String: Any])
    }

    private func decode(_ object: Any) throws -> ExportDocument {
        try ExportCodec.decode(JSONSerialization.data(withJSONObject: object))
    }

    @Test("R-DATA: lossless round trip with schema 1")
    func roundTrip() throws {
        let document = sample()
        let data = try ExportCodec.encode(document)
        let decoded = try ExportCodec.decode(data)
        #expect(decoded == document)
        #expect(decoded.schema == 1)
        #expect(try ExportCodec.encode(decoded) == data)
        #expect(try json(document)["schema"] as? Int == 1)
    }

    @Test("R-DATA: an empty export round trips")
    func empty() throws {
        let document = ExportDocument()
        #expect(try ExportCodec.decode(ExportCodec.encode(document)) == document)
    }

    @Test("R-DATA: not JSON or not an object")
    func notJSON() throws {
        #expect(throws: ImportError.notJSON) { try ExportCodec.decode(Data("hello".utf8)) }
        #expect(throws: ImportError.notJSON) { try ExportCodec.decode(Data()) }
        #expect(throws: ImportError.notAnObject) { try ExportCodec.decode(Data("[1,2]".utf8)) }
    }

    @Test("R-DATA: schema missing, wrong type or unsupported", arguments: [
        (#"{"habits":[]}"#, ImportError.missingSchema),
        (#"{"schema":"1"}"#, .invalidSchema),
        (#"{"schema":true}"#, .invalidSchema),
        (#"{"schema":1.5}"#, .invalidSchema),
        (#"{"schema":2,"habits":[],"completions":[],"reminders":[]}"#, .unsupportedSchema(2)),
        (#"{"schema":0}"#, .unsupportedSchema(0))
    ] as [(String, ImportError)])
    func schema(_ text: String, _ expected: ImportError) {
        #expect(throws: expected) { try ExportCodec.decode(Data(text.utf8)) }
    }

    @Test("R-DATA: missing or mistyped fields give a path")
    func malformedFields() throws {
        var root = try json(sample())
        root["completions"] = nil
        #expect(throws: ImportError.malformed(path: "", reason: "missing field \"completions\"")) { try decode(root) }

        root = try json(sample())
        var habits = try #require(root["habits"] as? [[String: Any]])
        habits[1]["name"] = 42
        root["habits"] = habits
        #expect(throws: ImportError.malformed(path: "habits[1].name", reason: "wrong type (expected String)")) {
            try decode(root)
        }

        root = try json(sample())
        habits = try #require(root["habits"] as? [[String: Any]])
        habits[0]["createdDay"] = "2026-02-30"
        root["habits"] = habits
        #expect(throws: ImportError.malformed(
            path: "habits[0].createdDay", reason: "\"2026-02-30\" is not a calendar day (yyyy-MM-dd)"
        )) { try decode(root) }

        root = try json(sample())
        habits = try #require(root["habits"] as? [[String: Any]])
        habits[0]["goal"] = ["kind": "timesPerWeek", "count": 8]
        root["habits"] = habits
        #expect(throws: ImportError.self) { try decode(root) }

        root = try json(sample())
        var reminders = try #require(root["reminders"] as? [[String: Any]])
        reminders[0]["time"] = ["hour": 25, "minute": 0]
        root["reminders"] = reminders
        #expect(throws: ImportError.malformed(
            path: "reminders[0].time", reason: "25:0 is not a time of day (00:00...23:59)"
        )) { try decode(root) }

        root = try json(sample())
        habits = try #require(root["habits"] as? [[String: Any]])
        habits[0]["archivedDay"] = NSNull()
        habits[0]["sortOrder"] = NSNull()
        root["habits"] = habits
        #expect(throws: ImportError.malformed(path: "habits[0].sortOrder", reason: "missing value (expected Int)")) {
            try decode(root)
        }
    }

    @Test("R-DATA: rule violations across records")
    func crossRecordRules() throws {
        var document = sample()
        document.habits[1].id = document.habits[0].id
        document.completions = []
        document.reminders = []
        #expect(throws: ImportError.duplicateID(path: "habits[1]", id: uuid(1))) {
            try ExportCodec.decode(ExportCodec.encode(document))
        }

        document = sample()
        document.completions.append(Completion(habitID: uuid(77), day: day("2026-11-01")))
        #expect(throws: ImportError.unknownHabit(path: "completions[2]", id: uuid(77))) {
            try ExportCodec.decode(ExportCodec.encode(document))
        }

        document = sample()
        document.completions.append(document.completions[0])
        #expect(throws: ImportError.duplicateCompletion(index: 2)) {
            try ExportCodec.decode(ExportCodec.encode(document))
        }

        document = sample()
        document.reminders[1].kind = .habit(uuid(78))
        #expect(throws: ImportError.unknownHabit(path: "reminders[1]", id: uuid(78))) {
            try ExportCodec.decode(ExportCodec.encode(document))
        }

        document = sample()
        document.reminders[1].id = document.reminders[0].id
        #expect(throws: ImportError.duplicateID(path: "reminders[1]", id: uuid(101))) {
            try ExportCodec.decode(ExportCodec.encode(document))
        }

        document = sample()
        document.habits[0].name = ""
        #expect(throws: ImportError.invalidHabit(index: 0, reason: HabitError.emptyName.description)) {
            try ExportCodec.decode(ExportCodec.encode(document))
        }

        document = sample()
        document.reminders.append(Reminder(
            id: uuid(103), kind: .general(label: "Other"), time: time(8, 30), weekdays: [.friday]
        ))
        #expect(throws: ImportError.invalidReminder(
            index: 2, reason: "Clashes with the reminder \"Water\" at 08:30 on Mon, Fri."
        )) { try ExportCodec.decode(ExportCodec.encode(document)) }
    }

    @Test("R-DATA: every import error reads as a sentence")
    func messages() {
        let errors: [ImportError] = [
            .notJSON, .notAnObject, .missingSchema, .invalidSchema, .unsupportedSchema(3),
            .malformed(path: "habits[0]", reason: "x"), .malformed(path: "", reason: "x"),
            .invalidHabit(index: 0, reason: "x"), .invalidReminder(index: 1, reason: "x"),
            .duplicateID(path: "habits[1]", id: uuid(1)), .duplicateCompletion(index: 0),
            .unknownHabit(path: "completions[0]", id: uuid(2))
        ]
        for error in errors {
            #expect(!error.description.isEmpty)
            #expect(error.description.hasSuffix(".") || error.description.hasSuffix("x"))
        }
        #expect(ImportError.unsupportedSchema(3).description.contains("3"))
        #expect(ImportError.malformed(path: "habits[0]", reason: "x").description.contains("habits[0]"))
    }
}

@Suite("Readable errors")
struct ReadableErrorTests {
    @Test("R-DATA R-REM R-LIST: localizedDescription shows the readable text")
    func localizedDescriptions() {
        let errors: [any Error] = [
            ImportError.unsupportedSchema(2),
            HabitError.emptyName,
            ReminderError.duplicate(of: uuid(1), message: "Clashes with the reminder \"Water\" at 08:00 on Mon."),
            GoalError.timesPerWeekOutOfRange(8)
        ]
        let expected = [
            "Schema 2 is not supported (this version reads schema 1).",
            "A habit needs a name.",
            "Clashes with the reminder \"Water\" at 08:00 on Mon.",
            "A weekly goal must be between 1 and 7 days, not 8."
        ]
        #expect(errors.map(\.localizedDescription) == expected)
    }

    @Test("R-DATA R-REM: an import with clashing habit reminders names the habit")
    func importHabitReminderClash() throws {
        let read = habit(1, created: "2026-10-01", name: "Read")
        let document = ExportDocument(
            habits: [read],
            reminders: [
                Reminder(id: uuid(101), kind: .habit(read.id), time: time(21, 0), weekdays: [.monday, .tuesday]),
                Reminder(id: uuid(102), kind: .habit(read.id), time: time(21, 0), weekdays: [.tuesday])
            ]
        )
        let error = ImportError.invalidReminder(
            index: 1, reason: "Clashes with the reminder for \"Read\" at 21:00 on Mon, Tue."
        )
        #expect(throws: error) { try ExportCodec.decode(ExportCodec.encode(document)) }
        #expect(error.localizedDescription
                == "Reminder 2 is invalid: Clashes with the reminder for \"Read\" at 21:00 on Mon, Tue.")
    }
}
