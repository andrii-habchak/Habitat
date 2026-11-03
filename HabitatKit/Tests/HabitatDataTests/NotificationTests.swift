import Foundation
import HabitatCore
import HabitatData
import Testing

@Suite("Notification scheduling")
struct NotificationTests {
    private let habit = Habit(
        id: UUID(), name: "Read", colorHex: "#3366CC", goal: .daily, createdDay: day("2026-03-01"), sortOrder: 0
    )
    private let now = LocalMoment(day: day("2026-03-11"), minuteOfDay: 7 * 60)

    @Test("R-REM: replacing pending requests removes first, then adds the plan, and returns it")
    func replaceAll() async throws {
        let fake = FakeNotificationScheduler()
        let reminders = [
            Reminder(kind: .habit(habit.id), time: time(21, 0), weekdays: Set(Weekday.allCases)),
            Reminder(kind: .general(label: "Plan"), time: time(8, 0), weekdays: [.wednesday])
        ]
        let scheduled = try await NotificationSync.replaceAllPending(
            using: fake, reminders: reminders, habits: [habit], completions: [], now: now
        )
        let calls = await fake.calls
        #expect(calls.count == 2)
        #expect(calls.first == .removeAllPendingRequests)
        #expect(calls.last == .add(scheduled))
        #expect(await fake.pending == scheduled)
        #expect(scheduled.count == 16)
        #expect(scheduled.first?.title == "Plan")
        #expect(scheduled.contains { $0.habitID == habit.id && $0.title == "Read" })
        #expect(Set(scheduled.map(\.identifier)).count == scheduled.count)
    }

    @Test("R-REM: a second replace drops the previous requests instead of piling up")
    func secondReplace() async throws {
        let fake = FakeNotificationScheduler()
        let reminder = Reminder(kind: .habit(habit.id), time: time(21, 0), weekdays: Set(Weekday.allCases))
        try await NotificationSync.replaceAllPending(
            using: fake, reminders: [reminder], habits: [habit], completions: [], now: now
        )
        // Habit done today: today's reminder is skipped on the next plan.
        let done = [Completion(habitID: habit.id, day: now.day)]
        let second = try await NotificationSync.replaceAllPending(
            using: fake, reminders: [reminder], habits: [habit], completions: done, now: now
        )
        #expect(second.count == 13)
        #expect(await fake.pending == second)
        #expect(await fake.calls.filter { $0 == .removeAllPendingRequests }.count == 2)
    }

    @Test("R-REM: no reminders clears everything and adds nothing")
    func empty() async throws {
        let fake = FakeNotificationScheduler()
        try await NotificationSync.replaceAllPending(using: fake, reminders: [], habits: [], completions: [], now: now)
        #expect(await fake.calls == [.removeAllPendingRequests, .add([])])
        #expect(await fake.pending.isEmpty)
    }

    @Test("R-REM: the cap of 60 requests holds")
    func cap() async throws {
        let fake = FakeNotificationScheduler()
        let reminders = (0..<6).map {
            Reminder(kind: .general(label: "R\($0)"), time: time(8, $0), weekdays: Set(Weekday.allCases))
        }
        let scheduled = try await NotificationSync.replaceAllPending(
            using: fake, reminders: reminders, habits: [], completions: [], now: now
        )
        #expect(scheduled.count == ReminderPlanner.maxRequests)
    }

    @Test("R-REM: the fake records authorization calls and moves its status")
    func authorization() async throws {
        let fake = FakeNotificationScheduler(status: .notDetermined, grantsAuthorization: false)
        #expect(await fake.authorizationStatus() == .notDetermined)
        #expect(try await fake.requestAuthorization() == false)
        #expect(await fake.authorizationStatus() == .denied)
        #expect(await fake.calls == [.authorizationStatus, .requestAuthorization, .authorizationStatus])
    }

    @Test("R-REM: the system scheduler conforms to the protocol (not called here)")
    func systemConformance() {
        let scheduler: any NotificationScheduling = UserNotificationScheduler()
        #expect(scheduler is UserNotificationScheduler)
    }
}
