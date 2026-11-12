import Foundation
import Testing
@testable import FuckingAdviceCore

@Test func corruptSettingsFallBackToDefaults() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SharedStore(groupID: "invalid.test.group", fallbackRoot: root)
    #expect(store.loadSettings().overlay.customText == "")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: root.appendingPathComponent("settings.json"))
    #expect(store.loadSettings().schemaVersion == 1)
}

@Test func modelDefaultsAreStable() {
    let profile = WidgetProfile.default
    #expect(profile.id == "default")
    #expect(profile.heading == "ADVICE OF THE DAY")
    #expect(PresentationSettings().schemaVersion == 1)
    #expect(PresentationSettings().automaticRefreshEnabled == false)
    #expect(PresentationSettings().automaticRefreshIntervalMinutes == 60)
}

@Test func legacySettingsDecodeWithAutomaticRefreshDisabled() throws {
    let data = Data(#"{"schemaVersion":1}"#.utf8)
    let settings = try JSONDecoder().decode(PresentationSettings.self, from: data)
    #expect(settings.widgetProfiles["default"]?.id == "default")
    #expect(settings.automaticRefreshEnabled == false)
    #expect(settings.automaticRefreshIntervalMinutes == 60)
}
