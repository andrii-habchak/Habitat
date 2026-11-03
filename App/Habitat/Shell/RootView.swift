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
///
/// The icon is decorative and kept outside the text element on purpose. With
/// `ContentUnavailableView { Label(...) }` the title's accessibility element spans the large
/// secondary-colour icon as well, so the contrast audit sampled the icon's grey pixels as the
/// text colour. The solid header band of the `calendar` symbol (Month tab) was enough to fail
/// `performAccessibilityAudit()`.
struct FeaturePlaceholder: View {
    let tab: AppTab

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: tab.systemImage)
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text(tab.title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("Not built yet.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.placeholder(tab))
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(tab.title)
        }
    }
}

#Preview {
    RootView()
}
