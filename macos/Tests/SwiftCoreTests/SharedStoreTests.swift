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
}
