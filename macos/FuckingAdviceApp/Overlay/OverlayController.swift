import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private weak var model: AppModel?
    private var window: NSWindow?

    init(model: AppModel) { self.model = model }

    func apply(_ enabled: Bool) {
        if enabled { show() } else { window?.orderOut(nil) }
    }

    func update() {
        guard let model, let window else { return }
        window.contentView = NSHostingView(rootView: OverlayView(model: model))
        position(window, settings: model.settings.overlay)
    }

    private func show() {
        guard let model else { return }
        if window == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.contentView = NSHostingView(rootView: OverlayView(model: model))
            window = panel
        }
        if let window { position(window, settings: model.settings.overlay); window.orderFrontRegardless() }
    }

    private func position(_ window: NSWindow, settings: OverlaySettings) {
        guard let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = NSSize(width: max(320, area.width * settings.widthFraction), height: max(150, area.height * settings.heightFraction))
        let origin = NSPoint(x: area.minX + area.width * settings.centerX - size.width / 2,
                             y: area.minY + area.height * (1 - settings.centerY) - size.height / 2)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

private struct OverlayView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        let settings = model.settings.overlay
        VStack(spacing: 9) {
            if settings.headingEnabled {
                Text(settings.heading).font(.system(size: max(11, settings.fontSize * 0.22), weight: .semibold, design: .rounded)).tracking(3)
            }
            Text(model.displayedText)
                .font(settings.fontName.map { .custom($0, size: settings.fontSize) } ?? .system(size: settings.fontSize, weight: .semibold, design: .rounded))
                .lineLimit(settings.maxLines).minimumScaleFactor(0.38).multilineTextAlignment(.center)
        }
        .foregroundStyle(textStyle(settings)).shadow(color: .white.opacity(settings.glow > 0 ? 0.35 : 0), radius: settings.glow)
        .shadow(color: .black.opacity(0.55), radius: settings.shadow, y: 2).padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(panel(settings)).opacity(settings.opacity)
        .accessibilityElement(children: .combine).accessibilityLabel(model.displayedText)
    }

    private func textStyle(_ settings: OverlaySettings) -> AnyShapeStyle {
        if settings.style == .gradient || settings.style == .translucent {
            return AnyShapeStyle(LinearGradient(colors: settings.gradientColors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color(hex: settings.textColor))
    }

    @ViewBuilder private func panel(_ settings: OverlaySettings) -> some View {
        if settings.panelEnabled { RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial).opacity(settings.panelOpacity) }
        else { Color.clear }
    }
}
