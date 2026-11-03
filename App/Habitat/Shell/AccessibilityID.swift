/// Accessibility identifiers follow `<screen>.<element>[.<id>]` (see `docs/accessibility-ids.md`).
///
/// - `screen`: lower camel case screen name (`habits`, `week`, `habitEditor`, `tabs`).
/// - `element`: lower camel case element name (`addButton`, `placeholder`, `row`).
/// - `id`: optional instance key, e.g. a habit's UUID or a `yyyy-MM-dd` day.
enum AccessibilityID {
    static func make(_ screen: String, _ element: String, _ id: String? = nil) -> String {
        [screen, element, id].compactMap(\.self).joined(separator: ".")
    }

    /// Tab bar item, e.g. `tabs.habits`.
    static func tab(_ tab: AppTab) -> String {
        make("tabs", tab.rawValue)
    }

    /// Placeholder content of a screen not built yet, e.g. `habits.placeholder`.
    static func placeholder(_ tab: AppTab) -> String {
        make(tab.rawValue, "placeholder")
    }
}
