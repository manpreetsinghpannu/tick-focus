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

enum ThemeColor: String, CaseIterable {
    case blue, grey

    var title: String { rawValue.capitalized }
}

private struct ThemeColorKey: EnvironmentKey {
    static let defaultValue = ThemeColor.blue
}

extension EnvironmentValues {
    var tickTheme: ThemeColor {
        get { self[ThemeColorKey.self] }
        set { self[ThemeColorKey.self] = newValue }
    }
}

/// All app colors. Blue light mode uses pure #0000FF; dark mode lifts it to #4D4DFF so it stays readable on near-black.
/// Grey follows the classic flip clock look: grey digits on near-black.
struct Palette {
    let bg, card, border, text, muted: Color
    let accent, onAccent, tonal, track, sliderTrack: Color
    let breakAccent, breakTrack: Color
    let flipBg, flipCard: Color

    static let blueLight = Palette(
        bg: Color(hex: 0xF6F6FF), card: .white, border: Color(hex: 0xD9D9F7),
        text: Color(hex: 0x0A0A3D), muted: Color(hex: 0x55557A),
        accent: Color(hex: 0x0000FF), onAccent: .white, tonal: Color(hex: 0xE2E2FF), track: Color(hex: 0xDCDCFF),
        sliderTrack: Color(hex: 0xD3D3DC),
        breakAccent: Color(hex: 0x3B4BFF), breakTrack: Color(hex: 0xDDE3FF),
        flipBg: Color(hex: 0xF6F6FF), flipCard: Color(hex: 0xE8E8FF))

    static let blueDark = Palette(
        bg: Color(hex: 0x0A0A12), card: Color(hex: 0x14141F), border: Color(hex: 0x26263D),
        text: Color(hex: 0xEDEDFF), muted: Color(hex: 0x9A9AC0),
        accent: Color(hex: 0x4D4DFF), onAccent: .white, tonal: Color(hex: 0x1E1E3A), track: Color(hex: 0x1C1C40),
        sliderTrack: Color(hex: 0x3A3A4C),
        breakAccent: Color(hex: 0x6B7BFF), breakTrack: Color(hex: 0x1C2148),
        flipBg: Color(hex: 0x05050C), flipCard: Color(hex: 0x11111F))

    static let greyLight = Palette(
        bg: Color(hex: 0xF5F5F7), card: .white, border: Color(hex: 0xDCDCE0),
        text: Color(hex: 0x1C1C1E), muted: Color(hex: 0x6E6E73),
        accent: Color(hex: 0x3A3A3C), onAccent: .white, tonal: Color(hex: 0xE5E5EA), track: Color(hex: 0xDCDCE0),
        sliderTrack: Color(hex: 0xD1D1D6),
        breakAccent: Color(hex: 0x6E6E73), breakTrack: Color(hex: 0xE5E5EA),
        flipBg: Color(hex: 0xF5F5F7), flipCard: Color(hex: 0xE5E5EA))

    static let greyDark = Palette(
        bg: Color(hex: 0x0B0B0C), card: Color(hex: 0x1C1C1E), border: Color(hex: 0x2C2C2E),
        text: Color(hex: 0xF2F2F7), muted: Color(hex: 0x98989D),
        accent: Color(hex: 0xB3B3B3), onAccent: Color(hex: 0x0B0B0C), tonal: Color(hex: 0x2C2C2E), track: Color(hex: 0x2A2A2C),
        sliderTrack: Color(hex: 0x3A3A3C),
        breakAccent: Color(hex: 0x8E8E93), breakTrack: Color(hex: 0x222224),
        flipBg: .black, flipCard: Color(hex: 0x0E0E0F))

    static func of(_ scheme: ColorScheme, _ theme: ThemeColor) -> Palette {
        switch (theme, scheme) {
        case (.blue, .dark): blueDark
        case (.blue, _): blueLight
        case (.grey, .dark): greyDark
        case (.grey, _): greyLight
        }
    }

    func accent(for phase: Phase) -> Color { phase.isBreak ? breakAccent : accent }
    func track(for phase: Phase) -> Color { phase.isBreak ? breakTrack : track }
}

/// The tall, condensed digit face used for every countdown (SF Pro Compressed).
enum DigitFont {
    static func font(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.compressed)
    }

    /// How far the text frame's center sits above the digits' visual center.
    /// Used to put the split line exactly through the middle of the numerals.
    static func centerOffset(_ size: CGFloat) -> CGFloat {
        let f = NSFont.systemFont(ofSize: size, weight: .bold, width: .compressed)
        let frameCenter = (f.ascender + f.descender) / 2
        return frameCenter - f.capHeight / 2
    }
}
