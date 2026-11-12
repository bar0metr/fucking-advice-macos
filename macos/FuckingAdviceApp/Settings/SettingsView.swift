import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        TabView {
            GeneralSettings(model: model).tabItem { Label("General", systemImage: "gear") }
            AdviceSettings(model: model).tabItem { Label("Advice", systemImage: "quote.bubble") }
            WidgetSettings(model: model).tabItem { Label("Widgets", systemImage: "rectangle.grid.2x2") }
            OverlaySettingsView(model: model).tabItem { Label("Desktop Text", systemImage: "textformat") }
            AboutView().tabItem { Label("About", systemImage: "info.circle") }
        }.padding(20)
    }
}

private struct GeneralSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(get: { model.settings.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            Toggle("Open Settings at launch", isOn: $model.settings.openSettingsAtLaunch).onChange(of: model.settings.openSettingsAtLaunch) { _, _ in model.saveSettings() }
            Section("Automatic refresh") {
                Toggle("Refresh advice automatically", isOn: $model.settings.automaticRefreshEnabled)
                    .onChange(of: model.settings.automaticRefreshEnabled) { _, _ in model.saveSettings() }
                Stepper(value: $model.settings.automaticRefreshIntervalMinutes, in: 5...1_440, step: 5) {
                    LabeledContent("Interval", value: refreshIntervalText)
                }
                .disabled(!model.settings.automaticRefreshEnabled)
                .onChange(of: model.settings.automaticRefreshIntervalMinutes) { _, _ in model.saveSettings() }
                Text("The timer runs while the menu-bar app is running. It starts a new countdown after each interval and never retries a failed request.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Status", value: model.status)
            Button("Reset All Settings") { model.settings = PresentationSettings(); model.saveSettings() }
        }.formStyle(.grouped)
    }

    private var refreshIntervalText: String {
        let minutes = model.settings.automaticRefreshIntervalMinutes
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }
}

private struct AdviceSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Section("Current advice") { Text(model.advice?.text ?? placeholderAdvice).textSelection(.enabled).font(.title3) }
            LabeledContent("Advice ID", value: model.advice.map { String($0.id) } ?? "—")
            LabeledContent("Last fetched", value: model.advice?.fetchedAt.formatted() ?? "Never")
            LabeledContent("API status", value: model.status)
            HStack { Button("Refresh Now") { model.refresh() }.disabled(model.isRefreshing); Button("Copy") { model.copyAdvice() } }
            Text("The app fetches at process launch, after Refresh Now, and at the configured interval when automatic refresh is enabled. Failed requests are not retried.").foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}

private struct WidgetSettings: View {
    @ObservedObject var model: AppModel
    @State private var selectedProfile = "default"
    private var profile: Binding<WidgetProfile> { Binding(get: { model.settings.widgetProfiles[selectedProfile] ?? fallback }, set: { model.settings.widgetProfiles[selectedProfile] = $0; model.saveSettings() }) }
    private var fallback: WidgetProfile { selectedProfile == "custom1" ? .custom1 : (selectedProfile == "custom2" ? .custom2 : .default) }
    private let fonts = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Form {
                Picker("Profile", selection: $selectedProfile) {
                    Text("Default").tag("default"); Text("Custom 1").tag("custom1"); Text("Custom 2").tag("custom2")
                }.pickerStyle(.segmented)
                Picker("Background", selection: profile.background) { ForEach(BackgroundStyle.allCases) { Text($0.rawValue.capitalized).tag($0) } }
                TextField("Primary color (hex)", text: color(0))
                TextField("Secondary color (hex)", text: color(1))
                Picker("Font", selection: fontName) { ForEach(fonts, id: \.self) { Text($0).tag($0) } }
                TextField("Heading", text: profile.heading)
                Toggle("Show heading", isOn: profile.headingEnabled)
                Slider(value: profile.fontSize, in: 12...36) { Text("Font size") }
                Slider(value: profile.opacity, in: 0.2...1) { Text("Opacity") }
                Slider(value: profile.padding, in: 6...28) { Text("Padding") }
                Picker("Alignment", selection: profile.alignment) { Text("Left").tag(0); Text("Center").tag(1); Text("Right").tag(2) }
                Button("Reset Widget Profile") { model.settings.widgetProfiles[selectedProfile] = fallback; model.saveSettings() }
            }.formStyle(.grouped).frame(width: 330)
            VStack(spacing: 18) {
                WidgetCardView(profile: profile.wrappedValue, text: model.advice?.text ?? placeholderAdvice).frame(width: 170, height: 170)
                WidgetCardView(profile: profile.wrappedValue, text: model.advice?.text ?? placeholderAdvice).frame(width: 340, height: 170)
                Text("Control-click the desktop → Edit Widgets → search for “Fucking Advice” → drag a widget to the desktop. The app cannot install or reposition widgets.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var fontName: Binding<String> { Binding(get: { profile.wrappedValue.fontName ?? "System" }, set: { profile.wrappedValue.fontName = $0 == "System" ? nil : $0 }) }
    private func color(_ index: Int) -> Binding<String> { Binding(get: { profile.wrappedValue.colors.indices.contains(index) ? profile.wrappedValue.colors[index] : "FFFFFF" }, set: { value in
        while profile.wrappedValue.colors.count <= index { profile.wrappedValue.colors.append("FFFFFF") }
        profile.wrappedValue.colors[index] = String(value.filter(\.isHexDigit).prefix(6)).uppercased()
    }) }
}

private struct OverlaySettingsView: View {
    @ObservedObject var model: AppModel
    private let fonts = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()
    var body: some View {
        Form {
            Toggle("Enable Desktop Text", isOn: $model.settings.overlay.enabled)
            Picker("Source", selection: $model.settings.overlay.source) { ForEach(OverlaySource.allCases) { Text($0.rawValue.capitalized).tag($0) } }
            if model.settings.overlay.source == .custom { TextEditor(text: $model.settings.overlay.customText).frame(height: 80) }
            Picker("Style", selection: $model.settings.overlay.style) { ForEach(OverlayStyle.allCases) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Font", selection: fontName) { ForEach(fonts, id: \.self) { Text($0).tag($0) } }
            Toggle("Show heading", isOn: $model.settings.overlay.headingEnabled)
            TextField("Heading", text: $model.settings.overlay.heading)
            Slider(value: $model.settings.overlay.fontSize, in: 24...110) { Text("Font size") }
            Slider(value: $model.settings.overlay.opacity, in: 0.25...1) { Text("Opacity") }
            Slider(value: $model.settings.overlay.glow, in: 0...20) { Text("Glow") }
            Toggle("Frosted backdrop panel", isOn: $model.settings.overlay.panelEnabled)
            Section("Desktop position") {
                LabeledContent("Horizontal") { Slider(value: $model.settings.overlay.centerX, in: 0.1...0.9) }
                LabeledContent("Vertical") { Slider(value: $model.settings.overlay.centerY, in: 0.1...0.9) }
                LabeledContent("Width") { Slider(value: $model.settings.overlay.widthFraction, in: 0.25...0.95) }
                LabeledContent("Height") { Slider(value: $model.settings.overlay.heightFraction, in: 0.12...0.6) }
            }
            HStack { Button("Apply") { model.saveSettings() }; Button("Reset Desktop Text") { model.settings.overlay = OverlaySettings(); model.saveSettings() } }
        }.formStyle(.grouped).onDisappear { model.saveSettings() }
    }

    private var fontName: Binding<String> { Binding(get: { model.settings.overlay.fontName ?? "System" }, set: { model.settings.overlay.fontName = $0 == "System" ? nil : $0 }) }
}

private struct AboutView: View {
    private let projectURL = URL(string: "https://github.com/bar0metr/fucking-advice-macos")!
    private let emailURL = URL(string: "mailto:bar0metr.crazy@yandex.com")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var licenseURL: URL {
        Bundle.main.url(forResource: "LICENSE", withExtension: nil)
            ?? projectURL.appending(path: "blob/main/LICENSE")
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

            VStack(spacing: 4) {
                Text("Fucking Advice").font(.largeTitle.bold())
                Text("Version \(version)").foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Created by Nikita Parfenovich")
                    .font(.headline)
                Text("aka bar0metr · © 2026")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Link(destination: projectURL) {
                    Label("Project on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: emailURL) {
                    Label("Email the author", systemImage: "envelope")
                }
            }
            .buttonStyle(.bordered)

            GroupBox {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GNU General Public License v3.0 only")
                            .font(.headline)
                        Text("This application is free software licensed under GPL-3.0-only.")
                            .foregroundStyle(.secondary)
                        Link("Read the license", destination: licenseURL)
                    }
                    Spacer()
                }
                .padding(4)
            }
            .frame(maxWidth: 470)

            Text("Native macOS host, WidgetKit extension, and Go networking helper. No analytics or tracking.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
