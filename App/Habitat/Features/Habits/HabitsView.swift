import HabitatCore
import SwiftUI

/// Habits screen (R-LIST, R-STREAK on the list): add, edit, archive, reorder.
struct HabitsView: View {
    @Environment(\.services) private var services
    @State private var model: HabitsViewModel?
    @State private var editor: HabitEditorModel?
    @State private var pendingArchive: HabitsViewModel.Row?
    @State private var showArchived = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    Color.clear
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.make("habits", "screen"))
            .navigationTitle("Habits")
            .toolbar { toolbar }
        }
        .task {
            if model == nil { model = HabitsViewModel(services: services) }
            model?.load()
        }
        .sheet(item: $editor, onDismiss: { model?.load() }, content: { HabitEditorView(model: $0) })
    }

    @ViewBuilder
    private func content(_ model: HabitsViewModel) -> some View {
        if model.active.isEmpty && model.archived.isEmpty {
            emptyState
        } else {
            list(model)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No habits yet", systemImage: "checklist")
        } description: {
            Text("Add a habit to start tracking it.")
        } actions: {
            Button("Add habit") { openNew() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.make("habits", "empty.add"))
        }
        .accessibilityIdentifier(AccessibilityID.make("habits", "empty"))
    }

    private func list(_ model: HabitsViewModel) -> some View {
        List {
            Section {
                ForEach(model.active) { row in
                    habitRow(row, archived: false)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                pendingArchive = row
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                            .accessibilityIdentifier(AccessibilityID.make("habits", "archive", row.id.uuidString))
                        }
                }
                .onMove { model.move(from: $0, to: $1) }
            }
            if !model.archived.isEmpty { archivedSection(model) }
        }
        .accessibilityIdentifier(AccessibilityID.make("habits", "list"))
        .confirmationDialog(
            "Archive this habit?",
            isPresented: Binding(get: { pendingArchive != nil }, set: { if !$0 { pendingArchive = nil } }),
            titleVisibility: .visible,
            presenting: pendingArchive
        ) { row in
            Button("Archive \(row.habit.name)", role: .destructive) {
                model.archive(id: row.id)
            }
            .accessibilityIdentifier(AccessibilityID.make("habits", "archiveConfirm"))
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It leaves the list; its history is kept and you can unarchive it later.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func archivedSection(_ model: HabitsViewModel) -> some View {
        Section {
            Toggle("Show archived", isOn: $showArchived.animation())
                .accessibilityIdentifier(AccessibilityID.make("habits", "showArchived"))
            if showArchived {
                ForEach(model.archived) { row in
                    habitRow(row, archived: true)
                        .swipeActions(edge: .trailing) {
                            Button {
                                model.unarchive(id: row.id)
                            } label: {
                                Label("Unarchive", systemImage: "tray.and.arrow.up")
                            }
                            .tint(.blue)
                            .accessibilityIdentifier(
                                AccessibilityID.make("habits", "unarchive", row.id.uuidString)
                            )
                        }
                }
            }
        } header: {
            Text("Archived")
        }
    }

    @ViewBuilder
    private func habitRow(_ row: HabitsViewModel.Row, archived: Bool) -> some View {
        let habit = row.habit
        let label = HabitFormat.accessibilityLabel(
            name: habit.name, goal: habit.goal, streak: row.streak, archived: archived
        )
        Button {
            editor = HabitEditorModel(services: services, editing: habit)
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Circle()
                    .fill(Color(hex: habit.colorHex))
                    .frame(width: Theme.Spacing.medium, height: Theme.Spacing.medium)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                    Text(habit.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(HabitFormat.goalText(habit.goal))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.small)
                HStack(spacing: Theme.Spacing.extraSmall) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(row.streak > 0 ? Theme.Status.inProgress : Color.secondary)
                    Text("\(row.streak)")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(String(localized: "Opens the editor"))
        .accessibilityIdentifier(AccessibilityID.make("habits", "row", habit.id.uuidString))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let model, model.active.count > 1 {
                EditButton()
                    .accessibilityIdentifier(AccessibilityID.make("habits", "edit"))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                openNew()
            } label: {
                Label("Add habit", systemImage: "plus")
            }
            .accessibilityIdentifier(AccessibilityID.make("habits", "add"))
        }
    }

    private func openNew() {
        editor = HabitEditorModel(services: services)
    }
}

extension HabitEditorModel: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    HabitsView()
}
