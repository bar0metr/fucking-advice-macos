import AppIntents
import SwiftUI
import WidgetKit

enum ProfileChoice: String, AppEnum {
    case defaultProfile, custom1, custom2
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Appearance Profile")
    static let caseDisplayRepresentations: [ProfileChoice: DisplayRepresentation] = [
        .defaultProfile: "Default", .custom1: "Custom 1", .custom2: "Custom 2"
    ]
    var key: String { self == .defaultProfile ? "default" : (self == .custom1 ? "custom1" : "custom2") }
}

struct AdviceWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Fucking Advice Appearance"
    @Parameter(title: "Profile", default: .defaultProfile) var profile: ProfileChoice
}

struct AdviceEntry: TimelineEntry { let date: Date; let advice: AdviceRecord?; let profile: WidgetProfile }

struct AdviceProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AdviceEntry { AdviceEntry(date: .now, advice: AdviceRecord(id: 19557, text: "Двигайся дальше, ёпта!", fetchedAt: .now), profile: .default) }
    func snapshot(for configuration: AdviceWidgetIntent, in context: Context) async -> AdviceEntry { entry(configuration) }
    func timeline(for configuration: AdviceWidgetIntent, in context: Context) async -> Timeline<AdviceEntry> { Timeline(entries: [entry(configuration)], policy: .never) }
    private func entry(_ configuration: AdviceWidgetIntent) -> AdviceEntry {
        let store = SharedStore(); let settings = store.loadSettings(allowFallback: false)
        return AdviceEntry(date: .now, advice: store.loadAdvice(allowFallback: false), profile: settings.widgetProfiles[configuration.profile.key] ?? .default)
    }
}

struct AdviceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AdviceEntry
    var body: some View {
        WidgetCardView(profile: entry.profile, text: entry.advice?.text ?? placeholderAdvice, usesSystemContainer: true)
            .containerBackground(for: .widget) { WidgetBackground(profile: entry.profile) }
            .accessibilityLabel(entry.advice?.text ?? placeholderAdvice)
    }
}

struct FuckingAdviceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: widgetKind, intent: AdviceWidgetIntent.self, provider: AdviceProvider()) { AdviceWidgetView(entry: $0) }
            .configurationDisplayName("Fucking Advice").description("The current cached advice.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
    }
}

@main struct FuckingAdviceWidgets: WidgetBundle { var body: some Widget { FuckingAdviceWidget() } }
