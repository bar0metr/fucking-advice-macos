import Foundation

final class SharedStore {
    enum StoreError: LocalizedError {
        case appGroupUnavailable(String)
        var errorDescription: String? {
            switch self { case .appGroupUnavailable(let id): return "App Group \(id) is unavailable. Configure matching signed entitlements for the app and widget." }
        }
    }

    private let fileManager: FileManager
    private let groupID: String
    private let fallbackRoot: URL?

    init(groupID: String = appGroupIdentifier, fileManager: FileManager = .default, fallbackRoot: URL? = nil) {
        self.groupID = groupID; self.fileManager = fileManager; self.fallbackRoot = fallbackRoot
    }

    private func root(allowFallback: Bool) throws -> URL {
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) { return group }
        if allowFallback {
            if let fallbackRoot { return fallbackRoot }
            let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return support.appendingPathComponent("FuckingAdvice", isDirectory: true)
        }
        throw StoreError.appGroupUnavailable(groupID)
    }

    func loadAdvice(allowFallback: Bool = true) -> AdviceRecord? {
        guard let data = try? Data(contentsOf: try root(allowFallback: allowFallback).appendingPathComponent("advice.json")),
              let envelope = try? Self.decoder.decode(AdviceEnvelope.self, from: data), envelope.schemaVersion == 1 else { return nil }
        return envelope.currentAdvice
    }

    func saveAdvice(_ advice: AdviceRecord) throws {
        try write(AdviceEnvelope(currentAdvice: advice), name: "advice.json")
    }

    func loadSettings(allowFallback: Bool = true) -> PresentationSettings {
        guard let data = try? Data(contentsOf: try root(allowFallback: allowFallback).appendingPathComponent("settings.json")),
              let value = try? Self.decoder.decode(PresentationSettings.self, from: data), value.schemaVersion == 1 else { return PresentationSettings() }
        return value
    }

    func saveSettings(_ settings: PresentationSettings) throws { try write(settings, name: "settings.json") }

    private func write<T: Encodable>(_ value: T, name: String) throws {
        let directory = try root(allowFallback: false)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; e.dateEncodingStrategy = .iso8601; return e }()
    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
}
