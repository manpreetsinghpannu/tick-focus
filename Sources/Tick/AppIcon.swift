import SwiftUI

enum IconStyle: String, CaseIterable {
    case midnight, blueGlass, frost, controlTile, flipCards, orb

    var title: String {
        switch self {
        case .midnight: "Midnight glass"
        case .blueGlass: "Blue glass"
        case .frost: "Frost"
        case .controlTile: "Control tile"
        case .flipCards: "Flip cards"
        case .orb: "Blue orb"
        }
    }
}

/// App icon artwork in the macOS Liquid Glass style, drawn on Apple's 1024pt icon grid
/// (824pt rounded square plus room for the shadow).
/// `Tick --icon <file.png> [style]` renders one; `Tick --icon-sheet <file.png>` renders all side by side.
/// make-icon.sh turns the chosen one into Assets/AppIcon.icns.
struct AppIconView: View {
    static let chosen: IconStyle = .midnight

    var style: IconStyle = AppIconView.chosen

    private static let blue = Color(hex: 0x0000FF)
    private static let brightBlue = Color(hex: 0x4D4DFF)
    private let tile = RoundedRectangle(cornerRadius: 185, style: .continuous)

    var body: some View {
        ZStack {
            background
                .frame(width: 824, height: 824)
                .clipShape(tile)
                .overlay(sheen)
                .overlay(rim)
                .shadow(color: .black.opacity(0.32), radius: 22, y: 12)
            artwork
        }
        .frame(width: 1024, height: 1024)
    }

    // MARK: Glass layers

    @ViewBuilder private var background: some View {
        switch style {
        case .midnight, .controlTile, .orb:
            LinearGradient(colors: [Color(hex: 0x3A3A44), Color(hex: 0x16161C)], startPoint: .top, endPoint: .bottom)
        case .blueGlass, .flipCards:
            LinearGradient(colors: [Color(hex: 0x5050FF), Self.blue, Color(hex: 0x0000B8)],
                           startPoint: .top, endPoint: .bottom)
        case .frost:
            LinearGradient(colors: [.white, Color(hex: 0xE2E4EE)], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Soft light pooling across the top, like light through glass.
    private var sheen: some View {
        Ellipse()
            .fill(.white.opacity(style == .frost ? 0.5 : 0.16))
            .frame(width: 760, height: 360)
            .blur(radius: 50)
            .offset(y: -300)
            .frame(width: 824, height: 824)
            .clipShape(tile)
            .allowsHitTesting(false)
    }

    /// Bright top edge fading out toward the bottom, then catching light again.
    private var rim: some View {
        let strength = style == .frost ? 0.9 : 0.55
        return tile
            .strokeBorder(LinearGradient(colors: [.white.opacity(strength), .white.opacity(0.06), .white.opacity(0.22)],
                                         startPoint: .top, endPoint: .bottom), lineWidth: 6)
            .frame(width: 824, height: 824)
    }

    // MARK: Artwork

    @ViewBuilder private var artwork: some View {
        switch style {
        case .midnight:
            ring(track: .white.opacity(0.12),
                 progress: AnyShapeStyle(LinearGradient(colors: [Self.brightBlue, Self.blue], startPoint: .top, endPoint: .bottom)),
                 glow: Self.blue)
            CutDigits(text: "25", size: 380, style: AnyShapeStyle(.white))
        case .blueGlass:
            ring(track: .white.opacity(0.22), progress: AnyShapeStyle(.white), glow: .white.opacity(0.5))
            CutDigits(text: "25", size: 380, style: AnyShapeStyle(.white))
        case .frost:
            ring(track: Self.blue.opacity(0.12),
                 progress: AnyShapeStyle(LinearGradient(colors: [Self.brightBlue, Self.blue], startPoint: .top, endPoint: .bottom)),
                 glow: Self.blue.opacity(0.5))
            CutDigits(text: "25", size: 380, style: AnyShapeStyle(Self.blue))
        case .controlTile:
            Circle()
                .fill(LinearGradient(colors: [.white, Color(hex: 0xE6E6EE)], startPoint: .top, endPoint: .bottom))
                .frame(width: 540, height: 540)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
            Image(systemName: "timer")
                .font(.system(size: 280, weight: .semibold))
                .foregroundStyle(Self.blue)
        case .flipCards:
            HStack(spacing: 26) {
                flipCard("2")
                flipCard("5")
            }
        case .orb:
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x7070FF), Self.blue, Color(hex: 0x00008C)],
                                     center: UnitPoint(x: 0.4, y: 0.3), startRadius: 20, endRadius: 360))
                .overlay(
                    Ellipse().fill(.white.opacity(0.35)).frame(width: 330, height: 150)
                        .blur(radius: 30).offset(x: -40, y: -190))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 4))
                .frame(width: 620, height: 620)
                .shadow(color: Self.blue.opacity(0.6), radius: 40, y: 10)
            CutDigits(text: "25", size: 360, style: AnyShapeStyle(.white))
        }
    }

    private func ring(track: Color, progress: AnyShapeStyle, glow: Color) -> some View {
        ZStack {
            Circle().stroke(track, lineWidth: 54)
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(progress, style: StrokeStyle(lineWidth: 54, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glow, radius: 26)
        }
        .frame(width: 600, height: 600)
    }

    private func flipCard(_ digit: String) -> some View {
        RoundedRectangle(cornerRadius: 64, style: .continuous)
            .fill(LinearGradient(colors: [.white, Color(hex: 0xE4E6F2)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 64, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 3))
            .frame(width: 270, height: 420)
            .overlay(CutDigits(text: digit, size: 400, style: AnyShapeStyle(Self.blue)))
            .overlay(Rectangle().fill(Self.blue.opacity(0.9)).frame(height: 10).blendMode(.destinationOut))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 20, y: 12)
    }

    // MARK: Rendering

    @MainActor
    static func render(_ style: IconStyle, to url: URL) {
        write(AppIconView(style: style), scale: 1, to: url)
    }

    /// All styles in a labeled grid, for picking one.
    @MainActor
    static func renderSheet(to url: URL) {
        let cell: CGFloat = 300
        let sheet = VStack(spacing: 30) {
            ForEach([Array(IconStyle.allCases.prefix(3)), Array(IconStyle.allCases.suffix(3))], id: \.self) { row in
                HStack(spacing: 30) {
                    ForEach(row, id: \.self) { style in
                        VStack(spacing: 6) {
                            AppIconView(style: style)
                                .scaleEffect(cell / 1024)
                                .frame(width: cell, height: cell)
                            HStack(alignment: .bottom, spacing: 14) {
                                AppIconView(style: style).scaleEffect(64 / 1024).frame(width: 64, height: 64)
                                AppIconView(style: style).scaleEffect(32 / 1024).frame(width: 32, height: 32)
                            }
                            Text("\((IconStyle.allCases.firstIndex(of: style) ?? 0) + 1). \(style.title)")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(40)
        .background(Color(hex: 0x24242A))
        write(sheet, scale: 2, to: url)
    }

    /// The given styles side by side in context: a Dock (dark and light) next to Apple's own app icons,
    /// plus Finder-list and Spotlight sizes.
    @MainActor
    static func renderComparison(_ styles: [IconStyle], to url: URL) {
        let neighbours = ["/System/Library/CoreServices/Finder.app", "/Applications/Safari.app",
                          "/System/Applications/Notes.app", "/System/Applications/Calendar.app",
                          "/System/Applications/System Settings.app"]
            .map { NSWorkspace.shared.icon(forFile: $0) }

        func dock(_ style: IconStyle, dark: Bool) -> some View {
            HStack(spacing: 10) {
                ForEach(neighbours.indices.prefix(3), id: \.self) { Image(nsImage: neighbours[$0]).resizable().frame(width: 72, height: 72) }
                AppIconView(style: style).scaleEffect(72 / 1024).frame(width: 72, height: 72)
                ForEach(neighbours.indices.suffix(2), id: \.self) { Image(nsImage: neighbours[$0]).resizable().frame(width: 72, height: 72) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(dark ? Color.white.opacity(0.14) : Color.white.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(dark ? 0.25 : 0.8), lineWidth: 1))
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: dark ? [Color(hex: 0x2A2A48), Color(hex: 0x101018)]
                                                     : [Color(hex: 0xDCE6F5), Color(hex: 0xB9C6DC)],
                                       startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }

        func smallRow(_ style: IconStyle, dark: Bool) -> some View {
            HStack(spacing: 10) {
                AppIconView(style: style).scaleEffect(36 / 1024).frame(width: 36, height: 36)
                Text("Tick Focus").font(.system(size: 15, weight: .medium))
                Spacer()
                AppIconView(style: style).scaleEffect(20 / 1024).frame(width: 20, height: 20)
                Text("Tick Focus.app").font(.system(size: 13))
            }
            .foregroundStyle(dark ? .white : .black)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(dark ? Color(hex: 0x2C2C30) : Color(hex: 0xF4F4F6), in: RoundedRectangle(cornerRadius: 12))
        }

        let sheet = HStack(alignment: .top, spacing: 36) {
            ForEach(styles, id: \.self) { style in
                VStack(spacing: 14) {
                    Text(style.title).font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                    HStack(spacing: 0) {
                        AppIconView(style: style).scaleEffect(240 / 1024).frame(width: 240, height: 240)
                            .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(hex: 0x1A1A1E))
                        AppIconView(style: style).scaleEffect(240 / 1024).frame(width: 240, height: 240)
                            .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(hex: 0xECECF0))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    label("Dock, dark mode")
                    dock(style, dark: true)
                    label("Dock, light mode")
                    dock(style, dark: false)
                    label("Finder and Spotlight sizes")
                    smallRow(style, dark: true)
                    smallRow(style, dark: false)
                }
                .frame(width: 620)
            }
        }
        .padding(36)
        .background(Color(hex: 0x111114))

        func label(_ text: String) -> some View {
            Text(text).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        write(sheet, scale: 2, to: url)
    }

    @MainActor
    private static func write<V: View>(_ view: V, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// Digits with a transparent cut through the middle, so whatever is behind shows through the gap.
private struct CutDigits: View {
    let text: String
    let size: CGFloat
    let style: AnyShapeStyle

    var body: some View {
        Text(text)
            .font(DigitFont.font(size))
            .foregroundStyle(style)
            .overlay {
                Rectangle()
                    .frame(height: size * 0.03)
                    .offset(y: DigitFont.centerOffset(size))
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}
