import Foundation
import HabitatCore
import HabitatData
import SwiftData
import Testing

@MainActor
@Suite("Seed fixtures and store")
struct SeedAndStoreTests {
    private func seeded(_ name: String, today: DayKey = testToday) throws -> (TestStore, ExportDocument) {
        let store = try TestStore(today: today)
        try SeedFixture.load(named: name, into: store.context, today: today)
        return (store, try store.snapshot())
    }

    @Test("R-DATA: empty fixture leaves the store empty")
    func empty() throws {
        let (_, document) = try seeded("empty")
        #expect(document == ExportDocument())
    }

    @Test("R-LIST R-MONTH R-REM: typical has five habits with daily and weekly goals, a week of completions, reminders")
    func typical() throws {
        let (store, document) = try seeded("typical")
        #expect(document.habits.count == 5)
        #expect(document.habits.contains { $0.goal == .daily } && document.habits.contains { $0.goal != .daily })
        #expect(document.reminders.count >= 2)
        let week = try store.completions.completions(from: testToday.adding(days: -6), through: testToday)
        #expect(!week.isEmpty && week.count == document.completions.count)
        #expect(Set(week.map(\.day)).count == 7)
        #expect(throws: Never.self) { try ExportCodec.validate(document) }
        #expect(try store.habits.active().count == 5)
    }

    @Test("R-STREAK: streaks fixture gives daily 10, daily 3 (today open) and weekly 4 for any today")
    func streaks() throws {
        // Every weekday as "today".
        for offset in 0..<7 {
            let today = testToday.adding(days: offset)
            let (store, document) = try seeded("streaks", today: today)
            let values = try document.habits.map { try store.completions.streak(habitID: $0.id) }
            #expect(values == [10, 3, 4], "today \(today)")
        }
    }

    @Test("R-DATA: fixtures are deterministic for the same today and move with today")
    func deterministic() throws {
        for fixture in SeedFixture.allCases {
            let first = fixture.document(today: testToday)
            #expect(first == fixture.document(today: testToday))
            #expect(try seeded(fixture.rawValue).1 == seeded(fixture.rawValue).1)
            if fixture != .empty {
                #expect(first != fixture.document(today: testToday.adding(days: 1)))
                #expect(first.habits.map(\.id) == fixture.document(today: testToday.adding(days: 1)).habits.map(\.id))
            }
        }
    }

    @Test("R-DATA: an unknown fixture name is an error naming the known ones")
    func unknown() throws {
        let store = try TestStore()
        #expect(throws: SeedError.unknownFixture("nope")) {
            try SeedFixture.load(named: "nope", into: store.context, today: testToday)
        }
        #expect(SeedError.unknownFixture("nope").description.contains("typical"))
    }

    @Test("R-DATA: a fixture is only loaded into an empty store")
    func notIntoNonEmpty() throws {
        let store = try TestStore()
        _ = try store.addHabit("Mine")
        try SeedFixture.load(named: "typical", into: store.context, today: testToday)
        #expect(try store.habits.all().map(\.name) == ["Mine"])
    }

    @Test("R-DATA: -uiTesting gives an in-memory store seeded from -seed; the data is not shared between containers")
    func prepare() throws {
        let configuration = StoreConfiguration(inMemory: true, seedFixture: "typical")
        let clock = FixedClock(day: testToday)
        let container = try HabitatStore.prepare(configuration, clock: clock)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<HabitModel>()) == 5)
        let other = try HabitatStore.prepare(StoreConfiguration(inMemory: true), clock: clock)
        #expect(try other.mainContext.fetchCount(FetchDescriptor<HabitModel>()) == 0)
        #expect(throws: SeedError.self) {
            try HabitatStore.prepare(StoreConfiguration(inMemory: true, seedFixture: "nope"), clock: clock)
        }
    }
}
