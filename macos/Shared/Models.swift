import AppKit
import Foundation
import SwiftUI

let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.example.fuckingadvicemacos"
let widgetKind = "FuckingAdviceWidget"
let placeholderAdvice = "No advice available yet."

struct AdviceRecord: Codable, Equatable, Sendable {
    let id: Int64
    let text: String
    let fetchedAt: Date
}

enum BackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case solid, gradient, glass, minimal
    var id: String { rawValue }
}

struct WidgetProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var background: BackgroundStyle
    var colors: [String]
    var angleDegrees: Double
    var opacity: Double
    var textColor: String
    var fontName: String?
    var fontSize: Double
    var fontWeight: Double
    var lineSpacing: Double
    var alignment: Int
    var headingEnabled: Bool
    var heading: String
    var cornerRadius: Double
    var padding: Double

    static let `default` = WidgetProfile(id: "default", name: "Default", background: .gradient,
        colors: ["223C68", "698FC0"], angleDegrees: 40, opacity: 0.9, textColor: "FFFFFF",
        fontName: nil, fontSize: 19, fontWeight: 0.55, lineSpacing: 2, alignment: 0,
        headingEnabled: true, heading: "ADVICE OF THE DAY", cornerRadius: 22, padding: 14)

    static let custom1: WidgetProfile = { var value = Self.default; value.id = "custom1"; value.name = "Custom 1"; return value }()
    static let custom2: WidgetProfile = { var value = Self.default; value.id = "custom2"; value.name = "Custom 2"; return value }()
}

enum OverlaySource: String, Codable, CaseIterable, Identifiable {
    case fetched, custom
    var id: String { rawValue }
}

enum OverlayStyle: String, Codable, CaseIterable, Identifiable {
    case solid, translucent, gradient, frosted
    var id: String { rawValue }
}

struct OverlaySettings: Codable, Equatable {
    var enabled = true
    var source: OverlaySource = .fetched
    var customText = ""
    var headingEnabled = true
    var heading = "ADVICE OF THE DAY"
    var fontName: String?
    var fontSize = 56.0
    var textColor = "FFFFFF"
    var gradientColors = ["FFFFFF", "9BCBFF"]
    var style: OverlayStyle = .translucent
    var opacity = 0.82
    var glow = 8.0
    var stroke = 0.5
    var shadow = 6.0
    var panelEnabled = false
    var panelOpacity = 0.24
    var widthFraction = 0.62
    var heightFraction = 0.24
    var centerX = 0.5
    var centerY = 0.84
    var maxLines = 5
}

struct PresentationSettings: Codable, Equatable {
    var schemaVersion = 1
    var widgetProfiles = ["default": WidgetProfile.default, "custom1": WidgetProfile.custom1, "custom2": WidgetProfile.custom2]
    var overlay = OverlaySettings()
    var launchAtLogin = false
    var openSettingsAtLaunch = false
}

struct AdviceEnvelope: Codable { var schemaVersion = 1; var currentAdvice: AdviceRecord? }

extension Color {
    init(hex: String, opacity: Double = 1) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255, opacity: opacity)
    }
}
