import SwiftUI

struct WidgetCardView: View {
    let profile: WidgetProfile
    let text: String
    var usesSystemContainer = false

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            if profile.headingEnabled { Text(profile.heading).font(.caption2.bold()).tracking(1.4) }
            Text(text)
                .font(profile.fontName.map { .custom($0, size: profile.fontSize) } ?? .system(size: profile.fontSize, weight: .semibold))
                .lineSpacing(profile.lineSpacing).minimumScaleFactor(0.48).lineLimit(7)
                .multilineTextAlignment(textAlignment)
        }
        .foregroundStyle(Color(hex: profile.textColor)).padding(profile.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .background {
            if !usesSystemContainer { WidgetBackground(profile: profile).clipShape(RoundedRectangle(cornerRadius: profile.cornerRadius)) }
        }
    }

    private var alignment: HorizontalAlignment { profile.alignment == 1 ? .center : (profile.alignment == 2 ? .trailing : .leading) }
    private var textAlignment: TextAlignment { profile.alignment == 1 ? .center : (profile.alignment == 2 ? .trailing : .leading) }
    private var frameAlignment: Alignment { profile.alignment == 1 ? .top : (profile.alignment == 2 ? .topTrailing : .topLeading) }

}

struct WidgetBackground: View {
    let profile: WidgetProfile
    @ViewBuilder var body: some View {
        switch profile.background {
        case .solid: Color(hex: profile.colors.first ?? "223C68", opacity: profile.opacity)
        case .gradient: LinearGradient(colors: profile.colors.map { Color(hex: $0, opacity: profile.opacity) }, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .glass: Rectangle().fill(.ultraThinMaterial)
        case .minimal: Color.clear
        }
    }
}
