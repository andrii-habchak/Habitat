import HabitatCore
import SwiftUI

/// Sheet for adding or editing a habit (R-LIST).
struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reminderSync) private var reminderSync
    @State private var model: HabitEditorModel

    init(model: HabitEditorModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                colorSection
                goalSection
            }
            .navigationTitle(model.isEditing ? "Edit habit" : "New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.make("habits", "editor.cancel"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save() {
                            reminderSync?.replan()
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.make("habits", "editor.save"))
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.make("habits", "editor"))
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $model.name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .onChange(of: model.name) { model.clearError() }
                .accessibilityIdentifier(AccessibilityID.make("habits", "editor.name"))
            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Status.failed)
                    .accessibilityIdentifier(AccessibilityID.make("habits", "editor.error"))
            }
        } header: {
            Text("Name")
        }
    }

    private var colorSection: some View {
        Section("Colour") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.minTapTarget))], spacing: Theme.Spacing.small) {
                ForEach(Theme.habitPalette, id: \.self) { hex in
                    swatch(hex)
                }
            }
            .padding(.vertical, Theme.Spacing.extraSmall)
        }
    }

    private func swatch(_ hex: String) -> some View {
        let selected = model.colorHex == hex
        return Button {
            model.colorHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .padding(Theme.Spacing.extraSmall)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 1)
                            .shadow(color: .black, radius: 1)
                    }
                }
                .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.colorName(hex))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.make("habits", "editor.color", String(hex.dropFirst())))
    }

    private var goalSection: some View {
        Section("Goal") {
            Picker("Goal", selection: $model.goalKind) {
                Text("Every day").tag(HabitEditorModel.GoalKind.daily)
                Text("Times a week").tag(HabitEditorModel.GoalKind.weekly)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.make("habits", "editor.goalKind"))
            if model.goalKind == .weekly {
                Stepper(
                    HabitFormat.goalText(.timesPerWeek(model.weeklyCount)),
                    value: $model.weeklyCount,
                    in: Goal.weeklyRange
                )
                .accessibilityIdentifier(AccessibilityID.make("habits", "editor.weeklyCount"))
            }
        }
    }

    /// Names for the palette entries, for VoiceOver.
    private static func colorName(_ hex: String) -> String {
        let names = [
            String(localized: "Red"), String(localized: "Orange"), String(localized: "Yellow"),
            String(localized: "Green"), String(localized: "Teal"), String(localized: "Blue"),
            String(localized: "Purple"), String(localized: "Pink")
        ]
        guard let index = Theme.habitPalette.firstIndex(of: hex), index < names.count else { return hex }
        return names[index]
    }
}
