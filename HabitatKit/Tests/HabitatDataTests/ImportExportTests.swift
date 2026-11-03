import Foundation
import HabitatCore
import HabitatData
import Testing

@MainActor
@Suite("Import and export")
struct ImportExportTests {
    private func uuid(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
    }

    private func habit(_ number: Int, order: Int? = nil, name: String? = nil) -> Habit {
        Habit(
            id: uuid(number), name: name ?? "Habit \(number)", colorHex: "#3366CC",
            goal: number.isMultiple(of: 2) ? .timesPerWeek(3) : .daily,
            createdDay: day("2026-03-01"), sortOrder: order ?? number)
    }

    private func encode(_ document: ExportDocument) throws -> Data {
        try ExportCodec.encode(document)
    }

    private func richStore() throws -> TestStore {
        let store = try TestStore()
        let read = try store.addHabit("Read")
        let run = try store.addHabit("Run", goal: .timesPerWeek(3))
        let old = try store.addHabit("Old")
        try store.completions.toggle(habitID: read.id, day: testToday)
        try store.completions.toggle(habitID: run.id, day: testToday)
        try store.habits.archive(id: old.id)
        try store.reminders.create(kind: .general(label: "Plan"), time: time(8, 0), weekdays: [.monday, .friday])
        try store.reminders.create(kind: .habit(read.id), time: time(21, 30), weekdays: Set(Weekday.allCases))
        return store
    }

    @Test("R-DATA: export then import (replace) into an empty store is lossless")
    func roundTripReplace() throws {
        let source = try richStore()
        let data = try source.transfer.exportData()
        let target = try TestStore()
        let summary = try target.transfer.importData(data, mode: .replace)
        #expect(summary.habitsAdded == 3 && summary.completionsAdded == 2 && summary.remindersAdded == 2)
        #expect(try target.snapshot() == source.snapshot())
        #expect(try target.transfer.exportData() == data)
    }

    @Test("R-DATA: export then import (merge) into an empty store keeps everything")
    func roundTripMerge() throws {
        let source = try richStore()
        let target = try TestStore()
        try target.transfer.importData(source.transfer.exportData(), mode: .merge)
        #expect(try target.snapshot() == source.snapshot())
    }

    @Test("R-DATA: importing a store's own export again is a no-op in both modes")
    func idempotent() throws {
        let store = try richStore()
        let before = try store.snapshot()
        let data = try store.transfer.exportData()
        let merged = try store.transfer.importData(data, mode: .merge)
        #expect(merged == ImportSummary())
        #expect(try store.snapshot() == before)
        let replaced = try store.transfer.importData(data, mode: .replace)
        #expect(replaced == ImportSummary())
        #expect(try store.snapshot() == before)
    }

    @Test("R-DATA: the exported file is schema 1 and keeps completions after an archive day")
    func exportShape() throws {
        let store = try TestStore(today: day("2026-03-20"))
        let archived = Habit(id: uuid(1), name: "A", colorHex: "#3366CC", goal: .daily, createdDay: day("2026-03-01"),
                             archivedDay: day("2026-03-05"), sortOrder: 0)
        let document = ExportDocument(
            habits: [archived], completions: [Completion(habitID: archived.id, day: day("2026-03-09"))]
        )
        try store.transfer.importData(encode(document), mode: .replace)
        let exported = try store.transfer.exportDocument()
        #expect(exported.schema == 1)
        #expect(exported.completions.count == 1)
    }

    @Test("R-DATA: merge adds new records after the existing ones and keeps existing habits as they are")
    func mergeAdds() throws {
        let store = try TestStore()
        let mine = try store.addHabit("Mine")
        let clash = habit(1, order: 0, name: "Imported")
        let incoming = ExportDocument(
            habits: [
                Habit(
                    id: mine.id, name: "Renamed in file", colorHex: "#000000", goal: .daily,
                    createdDay: testToday, sortOrder: 5
                ),
                habit(2, order: 7), clash
            ],
            completions: [
                Completion(habitID: clash.id, day: day("2026-03-02")), Completion(habitID: mine.id, day: testToday)
            ],
            reminders: [Reminder(id: uuid(50), kind: .habit(clash.id), time: time(7, 0), weekdays: [.monday])]
        )
        let summary = try store.transfer.importData(encode(incoming), mode: .merge)
        #expect(summary == ImportSummary(habitsAdded: 2, completionsAdded: 2, remindersAdded: 1))
        let habits = try store.habits.all()
        #expect(habits.map(\.name) == ["Mine", "Imported", "Habit 2"])
        #expect(habits.map(\.sortOrder) == [0, 1, 2])
        #expect(try store.habits.habit(id: mine.id)?.colorHex == "#3366CC")
        #expect(try store.reminders.all().count == 1)
    }

    @Test("R-DATA R-REM: merge validates reminder clashes against the existing store and changes nothing")
    func mergeClashWithStore() throws {
        let store = try TestStore()
        let mine = try store.addHabit("Mine")
        try store.reminders.create(kind: .habit(mine.id), time: time(8, 0), weekdays: [.monday, .tuesday])
        let before = try store.snapshot()
        let incoming = ExportDocument(
            habits: [habit(9), mine],
            completions: [Completion(habitID: uuid(9), day: day("2026-03-02"))],
            reminders: [
                Reminder(id: uuid(60), kind: .habit(uuid(9)), time: time(7, 0), weekdays: [.monday]),
                Reminder(id: uuid(61), kind: .habit(mine.id), time: time(8, 0), weekdays: [.tuesday, .friday])
            ]
        )
        // The file is valid on its own; only the store makes it clash.
        _ = try ExportCodec.decode(encode(incoming))
        do {
            try store.transfer.importData(encode(incoming), mode: .merge)
            Issue.record("expected a clash")
        } catch let error as ImportError {
            guard case let .invalidReminder(index, reason) = error else { Issue.record("wrong error \(error)"); return }
            #expect(index == 1)
            #expect(reason.contains("Mine"))
        }
        #expect(try store.snapshot() == before)
    }

    @Test("R-DATA: merge skips a file reminder whose id exists, and clashes inside the file are refused")
    func mergeReminderIDs() throws {
        let store = try TestStore()
        let general = try store.reminders.create(kind: .general(label: "Plan"), time: time(8, 0), weekdays: [.monday])
        let same = ExportDocument(reminders: [general])
        #expect(try store.transfer.importData(encode(same), mode: .merge) == ImportSummary())
        let pair = ExportDocument(reminders: [
            Reminder(id: uuid(70), kind: .general(label: "B"), time: time(9, 0), weekdays: [.tuesday]),
            Reminder(id: uuid(71), kind: .general(label: "C"), time: time(9, 0), weekdays: [.tuesday])
        ])
        #expect(throws: ImportError.self) { try store.transfer.importData(encode(pair), mode: .merge) }
        #expect(try store.reminders.all() == [general])
    }

    @Test("R-DATA: replace swaps everything, including records that are not in the file")
    func replaceSwaps() throws {
        let store = try richStore()
        let incoming = ExportDocument(
            habits: [habit(1)],
            completions: [Completion(habitID: uuid(1), day: day("2026-03-03"))],
            reminders: [Reminder(id: uuid(80), kind: .general(label: "Only"), time: time(6, 0), weekdays: [.sunday])]
        )
        let summary = try store.transfer.importData(encode(incoming), mode: .replace)
        #expect(summary == ImportSummary(
            habitsAdded: 1, completionsAdded: 1, remindersAdded: 1,
            habitsRemoved: 3, completionsRemoved: 2, remindersRemoved: 2
        ))
        #expect(try store.snapshot() == incoming)
    }

    @Test("R-DATA: replace works when the file reuses ids already in the store with other values")
    func replaceSameIDs() throws {
        let store = try TestStore()
        let mine = try store.addHabit("Mine")
        try store.completions.toggle(habitID: mine.id, day: testToday)
        let incoming = ExportDocument(
            habits: [Habit(id: mine.id, name: "Changed", colorHex: "#FFFFFF", goal: .timesPerWeek(2),
                           createdDay: day("2026-01-01"), sortOrder: 4)],
            completions: [Completion(habitID: mine.id, day: day("2026-01-02"))]
        )
        try store.transfer.importData(encode(incoming), mode: .replace)
        #expect(try store.snapshot() == incoming)
    }

    @Test("R-DATA: malformed files are refused with a readable error and the store is unchanged")
    func malformedLeavesStore() throws {
        let store = try richStore()
        let before = try store.snapshot()
        let good = try store.transfer.exportData()
        let text = String(bytes: good, encoding: .utf8) ?? ""
        let samples: [(String, Data)] = [
            ("not json", Data("hello".utf8)),
            ("empty", Data()),
            ("array", Data("[]".utf8)),
            ("no schema", Data("{\"habits\":[]}".utf8)),
            ("future schema", Data(text.replacingOccurrences(of: "\"schema\" : 1", with: "\"schema\" : 2").utf8)),
            ("bad goal", Data(text.replacingOccurrences(of: "\"count\" : 3", with: "\"count\" : 12").utf8)),
            ("truncated", Data(text.prefix(text.count / 2).utf8)),
            ("dangling completion", Data("""
                {"schema":1,"habits":[],"completions":[{"habitID":"\(uuid(1))","day":"2026-03-01"}],"reminders":[]}
                """.utf8))
        ]
        for (label, data) in samples {
            for mode in [ImportMode.merge, .replace] {
                do {
                    try store.transfer.importData(data, mode: mode)
                    Issue.record("\(label) should be refused")
                } catch let error as ImportError {
                    #expect(!error.localizedDescription.isEmpty, "\(label)")
                } catch {
                    Issue.record("\(label): unexpected \(error)")
                }
                #expect(try store.snapshot() == before, "\(label) \(mode)")
            }
        }
    }

    @Test("R-DATA: a replace file with a clash inside it changes nothing")
    func replaceInvalidAtomic() throws {
        let store = try richStore()
        let before = try store.snapshot()
        let clashing = ExportDocument(reminders: [
            Reminder(id: uuid(90), kind: .general(label: "A"), time: time(9, 0), weekdays: [.monday]),
            Reminder(id: uuid(91), kind: .general(label: "B"), time: time(9, 0), weekdays: [.monday])
        ])
        let data = try JSONEncoder().encode(clashing)
        #expect(throws: ImportError.self) { try store.transfer.importData(data, mode: .replace) }
        #expect(try store.snapshot() == before)
    }
}
