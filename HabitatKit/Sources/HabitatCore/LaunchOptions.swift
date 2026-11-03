/// Test hooks read from the process launch arguments.
///
/// Recognised arguments (anything else is ignored, so Xcode's own
/// `-NSDocumentRevisionsDebugMode YES` style arguments pass through):
///
/// - `-uiTesting`: use an in-memory store, nothing is written to disk.
/// - `-seed <fixture>`: load the named seed fixture on launch.
/// - `-today yyyy-MM-dd`: pin the clock to that calendar day.
/// - `-fakeNotifications`: use the fake notification scheduler.
///
/// A value that is missing or malformed (`-seed` followed by another flag,
/// `-today 2026-02-30`) is dropped rather than guessed, so a typo in a test
/// shows up as "no override" instead of a different date.
public struct LaunchOptions: Equatable, Sendable {
    public static let uiTestingFlag = "-uiTesting"
    public static let seedFlag = "-seed"
    public static let todayFlag = "-today"
    public static let fakeNotificationsFlag = "-fakeNotifications"

    /// Use an in-memory store.
    public var uiTesting: Bool
    /// Name of the seed fixture to load, if any.
    public var seed: String?
    /// Pinned "today", if any (given as `yyyy-MM-dd`).
    public var today: DayKey?
    /// Use the fake notification scheduler.
    public var fakeNotifications: Bool

    public init(
        uiTesting: Bool = false,
        seed: String? = nil,
        today: DayKey? = nil,
        fakeNotifications: Bool = false
    ) {
        self.uiTesting = uiTesting
        self.seed = seed
        self.today = today
        self.fakeNotifications = fakeNotifications
    }

    /// Options for a normal launch: no overrides.
    public static let standard = LaunchOptions()

    /// Parses launch arguments. The first element may be the executable path;
    /// it is ignored like any other unrecognised argument.
    public init(arguments: [String]) {
        self.init()
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            switch argument {
            case Self.uiTestingFlag:
                uiTesting = true
            case Self.fakeNotificationsFlag:
                fakeNotifications = true
            case Self.seedFlag:
                if let value = Self.value(after: index, in: arguments) {
                    seed = value
                    index += 1
                }
            case Self.todayFlag:
                if let value = Self.value(after: index, in: arguments) {
                    if let day = DayKey(value) { today = day }
                    index += 1
                }
            default:
                break
            }
            index += 1
        }
    }

    private static func value(after index: Int, in arguments: [String]) -> String? {
        let next = index + 1
        guard next < arguments.endIndex else { return nil }
        let value = arguments[next]
        guard !value.isEmpty, !value.hasPrefix("-") else { return nil }
        return value
    }
}
