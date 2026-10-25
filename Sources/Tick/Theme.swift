import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// All app colors: grey throughout (grey digits on near-black in dark mode).
/// The only colors are for hour goals: Cobalt when a day's hours are done, Brick when a day ended short.
struct Palette {
    let bg, card, border, text, muted: Color
    let accent, onAccent, tonal, track, sliderTrack: Color
    let breakAccent, breakTrack: Color
    let done = Color(hex: 0x0047AB)
    let missed = Color(hex: 0xB42318)

    static let light = Palette(
        bg: Color(hex: 0xF5F5F7), card: .white, border: Color(hex: 0xDCDCE0),
        text: Color(hex: 0x1C1C1E), muted: Color(hex: 0x6E6E73),
        accent: Color(hex: 0x3A3A3C), onAccent: .white, tonal: Color(hex: 0xE5E5EA), track: Color(hex: 0xDCDCE0),
        sliderTrack: Color(hex: 0xD1D1D6),
        breakAccent: Color(hex: 0x6E6E73), breakTrack: Color(hex: 0xE5E5EA))

    static let dark = Palette(
        bg: Color(hex: 0x0B0B0C), card: Color(hex: 0x1C1C1E), border: Color(hex: 0x2C2C2E),
        text: Color(hex: 0xF2F2F7), muted: Color(hex: 0x98989D),
        accent: Color(hex: 0xB3B3B3), onAccent: Color(hex: 0x0B0B0C), tonal: Color(hex: 0x2C2C2E), track: Color(hex: 0x2A2A2C),
        sliderTrack: Color(hex: 0x3A3A3C),
        breakAccent: Color(hex: 0x8E8E93), breakTrack: Color(hex: 0x222224))

    static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? dark : light }

    func accent(for phase: Phase) -> Color { phase.isBreak ? breakAccent : accent }
    func track(for phase: Phase) -> Color { phase.isBreak ? breakTrack : track }
}

/// Typefaces for the countdown digits. All ship with macOS, so nothing is bundled.
enum ClockFont: String, CaseIterable {
    case compressed, compressedLight, condensed, rounded, mono, newYork
    case dinCondensed, dinAlternate, futura, helveticaCondensed, avenirCondensed, impact

    var title: String {
        switch self {
        case .compressed: "SF Compressed"
        case .compressedLight: "SF Compressed Light"
        case .condensed: "SF Condensed"
        case .rounded: "SF Rounded"
        case .mono: "SF Mono"
        case .newYork: "New York"
        case .dinCondensed: "DIN Condensed"
        case .dinAlternate: "DIN Alternate"
        case .futura: "Futura Condensed"
        case .helveticaCondensed: "Helvetica Condensed"
        case .avenirCondensed: "Avenir Condensed"
        case .impact: "Impact"
        }
    }

    func nsFont(_ size: CGFloat) -> NSFont {
        func design(_ d: NSFontDescriptor.SystemDesign, _ weight: NSFont.Weight) -> NSFont {
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            return base.fontDescriptor.withDesign(d).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        }
        let fallback = NSFont.systemFont(ofSize: size, weight: .bold, width: .compressed)
        return switch self {
        case .compressed: fallback
        case .compressedLight: NSFont.systemFont(ofSize: size, weight: .light, width: .compressed)
        case .condensed: NSFont.systemFont(ofSize: size, weight: .bold, width: .condensed)
        case .rounded: design(.rounded, .bold)
        case .mono: NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        case .newYork: design(.serif, .bold)
        case .dinCondensed: NSFont(name: "DINCondensed-Bold", size: size) ?? fallback
        case .dinAlternate: NSFont(name: "DINAlternate-Bold", size: size) ?? fallback
        case .futura: NSFont(name: "Futura-CondensedExtraBold", size: size) ?? fallback
        case .helveticaCondensed: NSFont(name: "HelveticaNeue-CondensedBlack", size: size) ?? fallback
        case .avenirCondensed: NSFont(name: "AvenirNextCondensed-Bold", size: size) ?? fallback
        case .impact: NSFont(name: "Impact", size: size) ?? fallback
        }
    }
}

/// The digit face used for every countdown.
enum DigitFont {
    static var face: ClockFont = .compressed

    static func font(_ size: CGFloat, face: ClockFont = DigitFont.face) -> Font {
        Font(face.nsFont(size) as CTFont)
    }

    /// Largest size up to `size` at which "88 88" fits in `width`, since some faces run much wider than others.
    static func fitting(_ size: CGFloat, width: CGFloat, face: ClockFont = DigitFont.face) -> CGFloat {
        let digits = ("88" as NSString).size(withAttributes: [.font: face.nsFont(size)]).width
        let total = digits * 2 + size * 0.14
        return total > width ? size * width / total : size
    }

    /// How far the text frame's center sits above the digits' visual center.
    /// Used to put the split line exactly through the middle of the numerals.
    static func centerOffset(_ size: CGFloat, face: ClockFont = DigitFont.face) -> CGFloat {
        let f = face.nsFont(size)
        let frameCenter = (f.ascender + f.descender) / 2
        return frameCenter - f.capHeight / 2
    }
}
