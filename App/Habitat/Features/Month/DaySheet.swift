import HabitatCore
import SwiftUI

/// The day's habits with a toggle each (R-MONTH). Toggles are disabled for a future day.
struct DaySheet: View {
    let day: DayKey
    let habits: [Habit]
    let done: Set<DoneKey>
    let isFuture: Bool
    let onToggle: (Habit) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty {
                    Text("No habits were active on this day.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(habits) { habit in
                        row(habit)
                    }
                }
                if isFuture {
                    Text("Future days cannot be marked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("month.daySheet")
            .navigationTitle(MonthSymbols.dayName(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("month.daySheet.close")
                }
            }
        }
    }

    private func row(_ habit: Habit) -> some View {
        let isDone = done.contains(DoneKey(habitID: habit.id, day: day))
        return Button {
            onToggle(habit)
        } label: {
            HStack(spacing: Theme.Spacing.small) {
                Circle()
                    .fill(Color(hex: habit.colorHex))
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(habit.name)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(isDone ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(habit.name)
        .accessibilityValue(isDone ? "done" : "not done")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("month.daySheet.toggle.\(habit.id.uuidString)")
    }
}
