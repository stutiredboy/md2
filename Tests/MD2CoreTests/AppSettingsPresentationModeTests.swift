import Foundation
import Testing
@testable import MD2App

@MainActor
struct AppSettingsPresentationModeTests {
    private func makeSettings() -> AppSettings {
        let defaults = UserDefaults(suiteName: "AppSettingsPresentationModeTests-\(UUID().uuidString)")!
        return AppSettings(defaults: defaults)
    }

    @Test func fileBackedDocumentsUseDefaultMode() {
        let settings = makeSettings()
        settings.defaultMode = .read
        settings.newDocumentMode = .write

        #expect(settings.presentationMode(isFileBacked: true) == .read)
    }

    @Test func newDocumentsUseNewDocumentMode() {
        let settings = makeSettings()
        settings.defaultMode = .read
        settings.newDocumentMode = .write

        #expect(settings.presentationMode(isFileBacked: false) == .write)
    }

    @Test func newDocumentModeDefaultsToEditWhenUnset() {
        let settings = makeSettings()

        #expect(settings.newDocumentMode == .write)
        #expect(settings.presentationMode(isFileBacked: false) == .write)
    }

    @Test func newDocumentModeDoesNotAffectOpenedFileMode() {
        let settings = makeSettings()
        settings.newDocumentMode = .read

        #expect(settings.defaultMode == .write)
        #expect(settings.presentationMode(isFileBacked: true) == .write)
    }

    @Test func existingOpenedFileModePreferenceIsPreserved() {
        let suiteName = "AppSettingsPresentationModeTests-existing-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(EditorMode.read.rawValue, forKey: "MD2.DefaultMode")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.defaultMode == .read)
        #expect(settings.newDocumentMode == .write)
        #expect(settings.presentationMode(isFileBacked: true) == .read)
        #expect(settings.presentationMode(isFileBacked: false) == .write)
    }

    @Test func newDocumentModePersistsAcrossInstances() {
        let suiteName = "AppSettingsPresentationModeTests-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AppSettings(defaults: defaults)
        first.newDocumentMode = .read

        let second = AppSettings(defaults: defaults)
        #expect(second.newDocumentMode == .read)
    }

    @Test func sideBySideModePersistsForBothPreferences() {
        let suiteName = "AppSettingsPresentationModeTests-split-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AppSettings(defaults: defaults)
        first.defaultMode = .split
        first.newDocumentMode = .split

        let second = AppSettings(defaults: defaults)
        #expect(second.defaultMode == .split)
        #expect(second.newDocumentMode == .split)
        #expect(second.presentationMode(isFileBacked: true) == .split)
        #expect(second.presentationMode(isFileBacked: false) == .split)
    }

    @Test func unknownStoredModeFallsBackToEdit() {
        let suiteName = "AppSettingsPresentationModeTests-unknown-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("nonsense", forKey: "MD2.DefaultMode")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.defaultMode == .write)
    }
}
