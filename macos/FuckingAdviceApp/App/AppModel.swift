import AppKit
import Foundation
import ServiceManagement
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    enum StartupState { case idle, started }
    @Published private(set) var advice: AdviceRecord?
    @Published var settings: PresentationSettings
    @Published private(set) var isRefreshing = false
    @Published private(set) var status = "Ready"

    private let store = SharedStore()
    private let runner = FetcherRunner()
    private var startupState: StartupState = .idle
    private var automaticRefreshTask: Task<Void, Never>?
    private(set) lazy var overlay = OverlayController(model: self)

    init() { advice = store.loadAdvice(); settings = store.loadSettings() }

    var displayedText: String {
        settings.overlay.source == .custom && !settings.overlay.customText.isEmpty ? settings.overlay.customText : (advice?.text ?? placeholderAdvice)
    }

    func startOnce(openSettings: @escaping @MainActor () -> Void) {
        guard startupState == .idle else { return }
        startupState = .started; overlay.apply(settings.overlay.enabled)
        if settings.openSettingsAtLaunch { openSettings() }
        configureAutomaticRefresh()
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true; status = "Fetching…"
        Task {
            do {
                let fetched = try await runner.fetch()
                try store.saveAdvice(fetched)
                advice = fetched; status = "Updated \(fetched.fetchedAt.formatted(date: .abbreviated, time: .shortened))"
                overlay.update(); WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            } catch { status = error.localizedDescription }
            isRefreshing = false
        }
    }

    func saveSettings() {
        do {
            settings.automaticRefreshIntervalMinutes = min(max(settings.automaticRefreshIntervalMinutes, 5), 1_440)
            try store.saveSettings(settings)
            status = "Settings saved"; overlay.apply(settings.overlay.enabled); overlay.update()
            configureAutomaticRefresh()
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch { status = error.localizedDescription }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            settings.launchAtLogin = enabled; saveSettings()
        } catch { status = "Launch at Login: \(error.localizedDescription)" }
    }

    func copyAdvice() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(displayedText, forType: .string) }

    private func configureAutomaticRefresh() {
        automaticRefreshTask?.cancel()
        automaticRefreshTask = nil
        guard startupState == .started, settings.automaticRefreshEnabled else { return }

        let nanoseconds = UInt64(settings.automaticRefreshIntervalMinutes) * 60 * 1_000_000_000
        automaticRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }
}
