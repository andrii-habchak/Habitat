import HabitatCore
import SwiftUI

/// Week screen (R-WEEK, R-STREAK): one row per habit, Monday to Sunday, swipe back for earlier weeks.
struct WeekView: View {
    @Environment(\.services) private var services

    var body: some View {
        WeekScreen(model: WeekViewModel(services: services))
    }
}

private struct WeekScreen: View {
    @State var model: WeekViewModel

    init(model: WeekViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $model.weekOffset) {
                ForEach(-WeekViewModel.maxWeeksBack...0, id: \.self) { offset in
                    WeekPage(model: model, week: model.week(offset: offset), offset: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityIdentifier(AccessibilityID.make("week", "screen"))
            .navigationTitle(WeekFormat.rangeTitle(model.week(offset: model.weekOffset)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { model.goPrevious() }
                    } label: {
                        Label("Previous week", systemImage: "chevron.left")
                    }
                    .disabled(!model.canGoPrevious)
                    .accessibilityIdentifier(AccessibilityID.make("week", "previous"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { model.goNext() }
                    } label: {
                        Label("Next week", systemImage: "chevron.right")
                    }
                    .disabled(!model.canGoNext)
                    .accessibilityIdentifier(AccessibilityID.make("week", "next"))
                }
            }
        }
        .onAppear { model.reload() }
    }
}

private struct WeekPage: View {
    let model: WeekViewModel
    let week: Week
    let offset: Int

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let rows = model.pageRows[offset] ?? []
        Group {
            if !model.isNear(offset) || model.pageRows[offset] == nil {
                Color.clear
            } else if rows.isEmpty {
                ContentUnavailableView(
                    offset < 0 ? "No habits this week" : "No habits yet",
                    systemImage: "checklist",
                    description: Text(offset < 0
                        ? "None of your habits existed in this week."
                        : "Add a habit in the Habits tab and it shows up here.")
                )
                .accessibilityIdentifier(AccessibilityID.make("week", "emptyState", week.start.text))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        if !typeSize.isAccessibilitySize {
                            WeekdayHeader(week: week, today: model.today)
                        }
                        ForEach(rows) { row in
                            HabitCard(
                                row: row,
                                week: week,
                                today: model.today,
                                compact: !typeSize.isAccessibilitySize
                            ) { day in
                                model.toggle(habitID: row.habit.id, day: day)
                            }
                        }
                    }
                    .padding(Theme.Spacing.medium)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// Weekday letters and day numbers; today is highlighted.
private struct WeekdayHeader: View {
    let week: Week
    let today: DayKey

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week.days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(WeekFormat.weekdayLetter(day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(day.day)")
                        .font(.callout.weight(day == today ? .bold : .regular))
                        .foregroundStyle(day == today ? Color.white : Color.primary)
                        .frame(minWidth: 28, minHeight: 28)
                        .background(Circle().fill(day == today ? Color.accentColor : Color.clear))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(WeekFormat.spokenDay(day) + (day == today ? ", today" : ""))
            }
        }
        .padding(.horizontal, Theme.Spacing.medium)
    }
}

private struct HabitCard: View {
    let row: HabitWeekRow
    let week: Week
    let today: DayKey
    let compact: Bool
    let onToggle: (DayKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HabitHeader(row: row, week: week)
            if compact {
                HStack(spacing: 0) {
                    ForEach(row.cells) { cell in
                        DayToggle(row: row, cell: cell, today: today, onToggle: onToggle)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ForEach(row.cells) { cell in
                    HStack {
                        Text(WeekFormat.spokenDay(cell.day) + (cell.day == today ? " (today)" : ""))
                            .font(.body)
                        Spacer()
                        DayToggle(row: row, cell: cell, today: today, onToggle: onToggle)
                    }
                }
            }
        }
        .padding(Theme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct HabitHeader: View {
    let row: HabitWeekRow
    let week: Week

    private var habitID: String { "\(row.habit.id.uuidString).\(week.start.text)" }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            HStack(spacing: Theme.Spacing.small) {
                Circle()
                    .fill(Color(hex: row.habit.colorHex))
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(row.habit.name)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityIdentifier(AccessibilityID.make("week", "header", habitID))
                Spacer(minLength: Theme.Spacing.small)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.medium) { progress; streak }
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) { progress; streak }
            }
        }
    }

    @ViewBuilder private var progress: some View {
        if let weekly = row.progress {
            let status = weekly.status
            Label("\(weekly.done)/\(weekly.target)", systemImage: Self.symbol(status))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.color(status))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Goal \(weekly.target) days a week, \(weekly.done) done")
                .accessibilityValue(status.spoken)
                .accessibilityIdentifier(AccessibilityID.make("week", "progress", habitID))
        }
    }

    private var streak: some View {
        Label(WeekFormat.streakText(row.streak, weekly: row.isWeekly), systemImage: "flame")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Streak \(WeekFormat.streakText(row.streak, weekly: row.isWeekly))")
            .accessibilityValue("\(row.streak)")
            .accessibilityIdentifier(AccessibilityID.make("week", "streak", habitID))
    }

    private static func symbol(_ status: WeeklyStatus) -> String {
        switch status {
        case .met: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .inProgress: "clock"
        }
    }

    private static func color(_ status: WeeklyStatus) -> Color {
        switch status {
        case .met: Theme.Status.met
        case .failed: Theme.Status.failed
        case .inProgress: Theme.Status.inProgress
        }
    }
}

private struct DayToggle: View {
    let row: HabitWeekRow
    let cell: WeekCell
    let today: DayKey
    let onToggle: (DayKey) -> Void

    var body: some View {
        let color = Color(hex: row.habit.colorHex)
        Button {
            onToggle(cell.day)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .background(Circle().fill(cell.isDone ? color : Color.clear))
                if cell.isDone {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 32, height: 32)
            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
            .opacity(cell.isEnabled ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!cell.isEnabled)
        .accessibilityLabel(
            "\(row.habit.name), \(WeekFormat.spokenDay(cell.day))" + (cell.day == today ? ", today" : "")
        )
        .accessibilityValue(cell.isDone ? "done" : "not done")
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier(AccessibilityID.make("week", "cell", "\(row.habit.id.uuidString).\(cell.day.text)"))
    }
}

#Preview {
    WeekView()
}
