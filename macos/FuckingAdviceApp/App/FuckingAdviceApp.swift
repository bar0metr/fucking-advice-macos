import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private lazy var settingsWindowController = SettingsWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "quote.bubble.fill", accessibilityDescription: "Fucking Advice")
        rebuildMenu()
        model.startOnce(openSettings: { [weak self] in self?.showSettings() })
        model.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.rebuildMenu() } }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
    private func rebuildMenu() {
        let menu = NSMenu()
        let preview = String(model.displayedText.prefix(72)).replacingOccurrences(of: "\n", with: " ")
        let current = NSMenuItem(title: preview, action: nil, keyEquivalent: ""); current.isEnabled = false; menu.addItem(current)
        menu.addItem(.separator())
        menu.addItem(withTitle: model.isRefreshing ? "Refreshing…" : "Refresh Now", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(withTitle: "Copy Advice", action: #selector(copyAdvice), keyEquivalent: "c")
        menu.addItem(withTitle: model.settings.overlay.enabled ? "Hide Desktop Text" : "Show Desktop Text", action: #selector(toggleOverlay), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        if model.status != "Ready" { let status = NSMenuItem(title: model.status, action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status) }
        menu.addItem(.separator()); menu.addItem(withTitle: "Quit Fucking Advice", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }; statusItem.menu = menu
    }

    @objc private func refresh() { model.refresh() }
    @objc private func copyAdvice() { model.copyAdvice() }
    @objc private func toggleOverlay() { model.settings.overlay.enabled.toggle(); model.saveSettings() }
    @objc private func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func showSettings() {
        settingsWindowController.show()
    }
}

@MainActor
private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(model: AppModel) {
        let content = SettingsView(model: model)
            .frame(minWidth: 760, minHeight: 560)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "Fucking Advice Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.setFrameAutosaveName("FuckingAdviceSettingsWindow")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct FuckingAdviceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { SettingsView(model: delegate.model).frame(minWidth: 760, minHeight: 560) }
    }
}
