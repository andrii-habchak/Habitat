import HabitatCore
import SwiftUI
import UIKit

/// Sheet to create or edit a reminder: kind, label or habit, time, weekdays (R-REM).
struct ReminderEditorView: View {
    @State var model: ReminderEditorModel
    let onSaved: () -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let message = model.errorMessage {
                    Section {
                        ErrorText(message: message)
                            .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "error"))
                    }
                }
                Section {
                    Picker("Kind", selection: $model.kind) {
                        ForEach(ReminderEditorModel.Kind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "kind"))
                    targetField
                }
                Section {
                    DatePicker("Time", selection: $model.time, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "time"))
                }
                Section("Days") {
                    WeekdayChips(selection: model.weekdays, toggle: model.toggle)
                }
                if model.editing != nil {
                    Section {
                        Button("Delete Reminder", role: .destructive) {
                            if model.delete() {
                                onDeleted()
                                dismiss()
                            }
                        }
                        .frame(minHeight: Theme.minTapTarget)
                        .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "delete"))
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.make("reminders", "editor"))
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "cancel"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "save"))
                }
            }
        }
    }

    @ViewBuilder
    private var targetField: some View {
        switch model.kind {
        case .general:
            TextField("Label", text: $model.label, prompt: Text("Label, e.g. Drink water"))
                .accessibilityLabel("Label")
                .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "label"))
        case .habit:
            if model.habitChoices.isEmpty {
                Text("No active habits. Add a habit first.")
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "habit"))
            } else {
                Picker("Habit", selection: $model.habitID) {
                    ForEach(model.habitChoices) { habit in
                        Text(habit.isArchived ? "\(habit.name) (archived)" : habit.name)
                            .tag(Optional(habit.id))
                    }
                }
                .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "habit"))
            }
        }
    }

    private func save() {
        if model.save() {
            onSaved()
            dismiss()
        } else if let message = model.errorMessage {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

/// Monday-first weekday toggles. The state is in the accessibility value.
private struct WeekdayChips: View {
    let selection: Set<Weekday>
    let toggle: (Weekday) -> Void

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: Theme.Spacing.small)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.small) {
            ForEach(Weekday.allCases, id: \.self) { day in
                chip(day)
            }
        }
        .padding(.vertical, Theme.Spacing.extraSmall)
    }

    private func chip(_ day: Weekday) -> some View {
        let isOn = selection.contains(day)
        return Button {
            toggle(day)
        } label: {
            Text(day.shortName)
                .font(.subheadline.weight(isOn ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                .foregroundStyle(isOn ? Color(.systemBackground) : Color(.label))
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(isOn ? Color(.label) : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Color(.label), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ReminderFormat.fullName(day))
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityIdentifier(AccessibilityID.make("reminders", "editor", "weekday.\(day.rawValue)"))
    }
}
