import HabitatCore
import SwiftUI

/// Month screen (R-MONTH): Monday-first grid of donuts, habit filter, day sheet.
struct MonthView: View {
    @Environment(\.services) private var services
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Months from today's month; limited to +-10 years.
    @State private var monthOffset = 0
    @State private var habits: [Habit] = []
    @State private var done: Set<DoneKey> = []
    @State private var filter: UUID?
    @State private var selectedDay: SelectedDay?
    @State private var errorText: String?

    private static let maxOffset = 120

    private struct SelectedDay: Identifiable {
        let day: DayKey
        var id: Int { day.serial }
    }

    private var month: Month {
        Month(containing: services.today).adding(months: monthOffset)
    }

    private var compact: Bool { typeSize.isAccessibilitySize }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.extraSmall), count: MonthCellBuilder.columns)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.medium) {
                    header
                    filterChips
                    weekdayHeader
                    grid
                }
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.bottom, Theme.Spacing.medium)
            }
            .navigationTitle("Month")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("month.screen")
        .onAppear(perform: reload)
        .onChange(of: monthOffset) { reload() }
        .sheet(item: $selectedDay) { selected in
            DaySheet(
                day: selected.day,
                habits: habits.filter { $0.isActive(on: selected.day) }.sorted { $0.sortOrder < $1.sortOrder },
                done: done,
                isFuture: selected.day > services.today,
                onToggle: toggle,
                onClose: { selectedDay = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Could not save", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: Navigation

    private var header: some View {
        HStack {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
            }
            .disabled(monthOffset <= -Self.maxOffset)
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("month.previous")

            Text(MonthSymbols.title(month))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("month.title")

            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
            }
            .disabled(monthOffset >= Self.maxOffset)
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("month.next")
        }
    }

    // MARK: Filter

    private var filterHabits: [Habit] {
        habits.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.small) {
                chip(title: "All", colorHex: nil, selected: filter == nil, id: "month.filter.all") {
                    filter = nil
                }
                ForEach(filterHabits) { habit in
                    chip(
                        title: habit.name,
                        colorHex: habit.colorHex,
                        selected: filter == habit.id,
                        id: "month.filter.\(habit.id.uuidString)"
                    ) {
                        filter = habit.id
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.extraSmall)
        }
    }

    private func chip(
        title: String,
        colorHex: String?,
        selected: Bool,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.extraSmall) {
                if selected {
                    Image(systemName: "checkmark").font(.caption.bold())
                }
                if let colorHex {
                    Circle().fill(Color(hex: colorHex)).frame(width: 10, height: 10)
                }
                Text(title).lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .frame(minHeight: Theme.minTapTarget)
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .background(
                Capsule().fill(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
            )
            .overlay(Capsule().strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    // MARK: Grid

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                Text(MonthSymbols.header(weekday, compact: compact))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        let cells = MonthCellBuilder.cells(
            month: month,
            habits: habits,
            done: done,
            filter: effectiveFilter,
            today: services.today
        )
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.extraSmall) {
            ForEach(cells) { cell in
                dayCell(cell)
            }
        }
    }

    /// A filter whose habit no longer exists counts as "All".
    private var effectiveFilter: UUID? {
        filterHabits.contains { $0.id == filter } ? filter : nil
    }

    private func dayCell(_ cell: MonthDayCell) -> some View {
        Button {
            selectedDay = SelectedDay(day: cell.day)
        } label: {
            ZStack {
                DonutView(segments: cell.segments)
                Text("\(cell.day.day)")
                    .font(compact ? .caption2 : .caption)
                    .fontWeight(cell.isToday ? .heavy : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.primary)
                    .padding(Theme.Spacing.extraSmall)
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(cell.isToday ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(cell.isToday ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .opacity(cell.isInMonth ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: cell))
        .accessibilityValue(cell.valueText)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("month.day.\(cell.day.text)")
    }

    private func label(for cell: MonthDayCell) -> String {
        var text = MonthSymbols.dayName(cell.day)
        if cell.isToday { text += ", today" }
        if cell.activeCount == 0 {
            text += ", no habits"
        } else {
            text += ", \(cell.doneCount) of \(cell.activeCount) habits done"
        }
        return text
    }

    // MARK: Data

    private func reload() {
        let first = MonthCellBuilder.paddedGrid(for: month)
        guard let start = first.first?.day, let end = first.last?.day else { return }
        do {
            habits = try services.habitRepository().all()
            let completions = try services.completionRepository().completions(from: start, through: end)
            done = Set(completions.map { DoneKey(habitID: $0.habitID, day: $0.day) })
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func toggle(_ habit: Habit) {
        guard let day = selectedDay?.day else { return }
        do {
            try services.completionRepository().toggle(habitID: habit.id, day: day)
            reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    MonthView()
}
