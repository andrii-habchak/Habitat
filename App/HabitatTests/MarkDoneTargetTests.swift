import Foundation
import HabitatCore
import Testing
@testable import Habitat

/// R-REM: the "Mark done" notification action finds its habit and day.
@Suite("MarkDoneTarget (R-REM)")
struct MarkDoneTargetTests {
    private let reminderID = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
    private let habitID = "0E984725-C51C-4BF4-9960-E1C80E27ABA0"

    @Test("parses reminder id, day and habit")
    func parses() throws {
        let target = try #require(MarkDoneTarget(identifier: "\(reminderID).2026-11-04", habitIDText: habitID))
        #expect(target.habitID == UUID(uuidString: habitID))
        #expect(target.day == DayKey("2026-11-04"))
    }

    @Test("rejects a missing or malformed habit id")
    func badHabit() {
        #expect(MarkDoneTarget(identifier: "\(reminderID).2026-11-04", habitIDText: nil) == nil)
        #expect(MarkDoneTarget(identifier: "\(reminderID).2026-11-04", habitIDText: "nope") == nil)
    }

    @Test("rejects a malformed identifier or day")
    func badIdentifier() {
        #expect(MarkDoneTarget(identifier: "no-separator", habitIDText: habitID) == nil)
        #expect(MarkDoneTarget(identifier: "nope.2026-11-04", habitIDText: habitID) == nil)
        #expect(MarkDoneTarget(identifier: "\(reminderID).2026-13-40", habitIDText: habitID) == nil)
        #expect(MarkDoneTarget(identifier: "\(reminderID).", habitIDText: habitID) == nil)
    }
}
