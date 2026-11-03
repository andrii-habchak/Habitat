import Foundation
import HabitatCore
import HabitatData
import Observation

/// Logic of the Settings screen: build the export file, read and import a picked file.
@MainActor
@Observable
final class SettingsModel {
    /// Temp file ready to share; set by `prepareExport()`.
    var exportURL: URL?
    var exportError: String?
    /// File picked and waiting for the Merge / Replace choice.
    var pendingImport: Data?
    var importSummary: ImportSummary?
    var importError: String?

    @ObservationIgnored private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    /// `habitat-export-<yyyy-MM-dd>.json`, the day from the injected clock.
    var exportFileName: String { "habitat-export-\(services.today.text).json" }

    func prepareExport() {
        exportError = nil
        discardExport()
        do {
            let data = try services.dataTransfer().exportData()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(exportFileName)
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Removes the temp file and forgets it.
    func discardExport() {
        if let url = exportURL { try? FileManager.default.removeItem(at: url) }
        exportURL = nil
    }

    /// Reads the picked file (security scoped) and asks for the mode.
    func filePicked(_ result: Result<URL, Error>) {
        importSummary = nil
        importError = nil
        switch result {
        case let .failure(error):
            importError = error.localizedDescription
        case let .success(url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try Data(contentsOf: url)
            } catch {
                importError = "The file could not be read: \(error.localizedDescription)"
            }
        }
    }

    /// Imports the pending file. Returns true on success (the caller re-plans reminders).
    func runImport(_ mode: ImportMode) -> Bool {
        guard let data = pendingImport else { return false }
        pendingImport = nil
        do {
            importSummary = try services.dataTransfer().importData(data, mode: mode)
            return true
        } catch {
            importError = error.localizedDescription
            return false
        }
    }

    func cancelImport() {
        pendingImport = nil
    }

    static func summaryText(_ summary: ImportSummary) -> String {
        var parts = [
            "Added \(summary.habitsAdded) habits, \(summary.completionsAdded) check-ins, "
                + "\(summary.remindersAdded) reminders."
        ]
        if summary.habitsRemoved + summary.completionsRemoved + summary.remindersRemoved > 0 {
            parts.append(
                "Removed \(summary.habitsRemoved) habits, \(summary.completionsRemoved) check-ins, "
                    + "\(summary.remindersRemoved) reminders."
            )
        }
        return parts.joined(separator: " ")
    }

    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Habitat"
    }

    static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
