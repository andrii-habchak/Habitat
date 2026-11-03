import HabitatCore
import HabitatData
import SwiftUI
import UIKit

/// Reminders screen (R-REM): general and per-habit reminders, add/edit/delete, permission state.
struct RemindersView: View {
    @Environment(\.services) private var services
    @Environment(\.reminderSync) private var reminderSync

    var body: some View {
        RemindersScreen(
            services: services,
            sync: reminderSync ?? ReminderSync(services: services, scheduler: FakeNotificationScheduler())
        )
    }
}

/// Which editor sheet is open.
private enum EditorTarget: Identifiable {
    case new
    case edit(Reminder)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(reminder): reminder.id.uuidString
        }
    }

    var reminder: Reminder? {
        if case let .edit(reminder) = self { return reminder }
        return nil
    }
}

private struct RemindersScreen: View {
    @State private var model: RemindersViewModel
    @State private var editorTarget: EditorTarget?
    @Environment(\.openURL) private var openURL

    init(services: AppServices, sync: ReminderSync) {
        _model = State(initialValue: RemindersViewModel(services: services, sync: sync))
    }

    var body: some View {
        NavigationStack {
            List {
                permissionSection
                if let message = model.errorMessage {
                    Section {
                        ErrorText(message: message)
                            .accessibilityIdentifier(AccessibilityID.make("reminders", "error"))
                    }
                }
                if model.isEmpty {
                    emptySection
                } else {
                    ForEach(model.sections) { section in
                        Section(section.title) {
                            ForEach(section.rows) { row in
                                rowButton(row)
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.make("reminders", "screen"))
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .new
                    } label: {
                        Label("Add reminder", systemImage: "plus")
                    }
                    .accessibilityIdentifier(AccessibilityID.make("reminders", "add"))
                }
            }
            .sheet(item: $editorTarget) { target in
                ReminderEditorView(
                    model: ReminderEditorModel(
                        services: model.services, editing: target.reminder, habits: model.habits
                    ),
                    onSaved: { model.didSave() },
                    onDeleted: { model.didDelete() }
                )
            }
            .onAppear {
                model.load()
                Task { await model.sync.refreshAuthorization() }
            }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        if model.showsDeniedBanner {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Label {
                        Text("Notifications are off")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "bell.slash")
                            .accessibilityHidden(true)
                    }
                    Text(
                        "Your reminders are saved, but they cannot alert you until you allow "
                            + "notifications for Habitat in Settings."
                    )
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.primary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.make("reminders", "permissionBanner"))
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .frame(minHeight: Theme.minTapTarget)
                .accessibilityHint("Opens Habitat's notification settings")
                .accessibilityIdentifier(AccessibilityID.make("reminders", "openSettings"))
            }
        } else if model.showsAllowButton {
            Section {
                Button {
                    model.requestAuthorization()
                } label: {
                    Label("Allow notifications", systemImage: "bell.badge")
                }
                .frame(minHeight: Theme.minTapTarget)
                .accessibilityHint("Asks for permission to show reminder notifications")
                .accessibilityIdentifier(AccessibilityID.make("reminders", "allowNotifications"))
            } footer: {
                Text("Habitat asks once. Reminders only alert you when notifications are allowed.")
                    .foregroundStyle(.primary)
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: Theme.Spacing.small) {
                Text("No reminders yet")
                    .font(.headline)
                Text("Tap + to add a general reminder or one for a habit.")
                    .font(.subheadline)
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.medium)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.make("reminders", "empty"))
        }
    }

    private func rowButton(_ row: ReminderRow) -> some View {
        Button {
            editorTarget = .edit(row.reminder)
        } label: {
            ReminderRowView(row: row)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint("Opens the reminder to edit it")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(AccessibilityID.make("reminders", "row", row.id.uuidString))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                model.delete(row.reminder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct ReminderRowView: View {
    let row: ReminderRow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text(row.title)
                .font(.body)
            HStack(spacing: Theme.Spacing.small) {
                Text(row.timeText)
                    .font(.subheadline.monospacedDigit())
                Text(row.daysText)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// An error line in a readable colour (4.5:1 or better), with an icon so colour is not the only cue.
struct ErrorText: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.Status.failed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    RemindersView()
}
