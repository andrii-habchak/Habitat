import SwiftUI

/// Tab shell. Each feature owns its screen under `Features/<Name>/`.
struct RootView: View {
    @State private var selection: AppTab = .habits

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                screen(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                            .accessibilityIdentifier(AccessibilityID.tab(tab))
                    }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .habits: HabitsView()
        case .week: WeekView()
        case .month: MonthView()
        case .reminders: RemindersView()
        case .settings: SettingsView()
        }
    }
}

/// Stand-in content for a screen that a later phase builds.
struct FeaturePlaceholder: View {
    let tab: AppTab

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(tab.title, systemImage: tab.systemImage)
            } description: {
                Text("Not built yet.")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.placeholder(tab))
            .navigationTitle(tab.title)
        }
    }
}

#Preview {
    RootView()
}
