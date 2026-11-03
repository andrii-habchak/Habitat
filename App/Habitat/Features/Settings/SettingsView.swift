import HabitatData
import SwiftUI
import UniformTypeIdentifiers

/// Settings screen (R-DATA): export and import, about.
struct SettingsView: View {
    @Environment(\.services) private var services
    @State private var model: SettingsModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    SettingsScreen(model: model)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            if model == nil { model = SettingsModel(services: services) }
        }
        .accessibilityIdentifier("settings.screen")
    }
}

private struct SettingsScreen: View {
    @Bindable var model: SettingsModel
    @Environment(\.reminderSync) private var reminderSync
    @State private var showImporter = false
    @State private var showShare = false

    var body: some View {
        List {
            Section {
                Button {
                    model.prepareExport()
                    showShare = model.exportURL != nil
                } label: {
                    Label("Export data", systemImage: "square.and.arrow.up")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .accessibilityIdentifier("settings.export")
                .accessibilityHint("Saves all habits and check-ins to a JSON file you can share")
                if let message = model.exportError {
                    ErrorText(message: message)
                        .accessibilityIdentifier("settings.exportError")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Import data", systemImage: "square.and.arrow.down")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .accessibilityIdentifier("settings.import")
                .accessibilityHint("Reads a Habitat JSON file")
                if let summary = model.importSummary {
                    Label {
                        Text("Import finished. \(SettingsModel.summaryText(summary))")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.Status.met)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.importResult")
                }
                if let message = model.importError {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                        ErrorText(message: message)
                        Text("Nothing was changed.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("settings.importError")
                }
            } header: {
                Text("Data")
            }

            Section {
                LabeledContent("App", value: SettingsModel.appName)
                LabeledContent("Version", value: SettingsModel.versionText)
                Text("Data stays on this device.")
                    .foregroundStyle(.primary)
            } header: {
                Text("About")
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = model.exportURL {
                ShareSheet(url: url).ignoresSafeArea()
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            model.filePicked(result)
        }
        .confirmationDialog(
            "Import data", isPresented: pendingBinding, titleVisibility: .visible
        ) {
            Button("Merge") { finish(.merge) }
                .accessibilityIdentifier("settings.import.merge")
            Button("Replace", role: .destructive) { finish(.replace) }
                .accessibilityIdentifier("settings.import.replace")
            Button("Cancel", role: .cancel) { model.cancelImport() }
        } message: {
            Text("Merge adds what is new and keeps your current data. "
                + "Replace overwrites all current data with the file.")
        }
    }

    private var pendingBinding: Binding<Bool> {
        Binding(
            get: { model.pendingImport != nil },
            set: { if !$0 { model.cancelImport() } }
        )
    }

    private func finish(_ mode: ImportMode) {
        if model.runImport(mode) { reminderSync?.replan() }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
