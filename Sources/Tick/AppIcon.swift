import SwiftUI

enum IconStyle: String, CaseIterable {
    case midnight, blueGlass, frost, controlTile, flipCards, orb
    // Focus-scheduler concepts, in the app's graphite + Cobalt/Brick palette.
    case weekGrid, ringDays, hourglass, focusDial, timeBlocks, checkRing
    // "On Track" concepts.
    case railTrack, runningTrack, milestonePath, dayRing, compass, trendLine, dotGrid, calendarCheck

    static let onTrackConcepts: [IconStyle] = [.railTrack, .runningTrack, .milestonePath, .dayRing,
                                               .compass, .trendLine, .dotGrid, .calendarCheck, .weekGrid]

    static let schedulerConcepts: [IconStyle] = [.weekGrid, .ringDays, .hourglass, .focusDial, .timeBlocks, .checkRing]

    var title: String {
        switch self {
        case .midnight: "Midnight glass"
        case .blueGlass: "Blue glass"
        case .frost: "Frost"
        case .controlTile: "Control tile"
        case .flipCards: "Flip cards"
        case .orb: "Blue orb"
        case .weekGrid: "Week grid"
        case .ringDays: "Ring + days"
        case .hourglass: "Hourglass"
        case .focusDial: "Focus dial"
        case .timeBlocks: "Time blocks"
        case .checkRing: "Check ring"
        case .railTrack: "Rail track"
        case .runningTrack: "Running track"
        case .milestonePath: "Milestone path"
        case .dayRing: "Day ring"
        case .compass: "Compass"
        case .trendLine: "Trend line"
        case .dotGrid: "Dot grid"
        case .calendarCheck: "Calendar check"
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
        case .midnight, .controlTile, .orb, .weekGrid, .ringDays, .hourglass, .focusDial, .timeBlocks, .checkRing,
             .railTrack, .runningTrack, .milestonePath, .dayRing, .compass, .trendLine, .dotGrid, .calendarCheck:
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

    private static let cobalt = LinearGradient(colors: [Color(hex: 0x3D7BFF), Color(hex: 0x0047AB)],
                                               startPoint: .top, endPoint: .bottom)
    private static let brick = LinearGradient(colors: [Color(hex: 0xE5523F), Color(hex: 0xB42318)],
                                              startPoint: .top, endPoint: .bottom)
    private static let graphite = LinearGradient(colors: [Color(hex: 0x6A6A74), Color(hex: 0x44444C)],
                                                 startPoint: .top, endPoint: .bottom)

    /// d = done (Cobalt), m = missed (Brick), t = today (graphite), f = ahead (outline).
    private func dayCell(_ kind: Character, _ size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        return ZStack {
            switch kind {
            case "d": shape.fill(Self.cobalt)
            case "m": shape.fill(Self.brick)
            case "t": shape.fill(Self.graphite)
            default: shape.strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: size * 0.04, dash: [size * 0.1, size * 0.07]))
            }
            if kind != "f" {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                   lineWidth: size * 0.025)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: kind == "d" ? Color(hex: 0x1F5FD6).opacity(0.45) : .clear, radius: size * 0.12)
    }

    private func dayGrid(_ rows: [String], cell: CGFloat, gap: CGFloat) -> some View {
        VStack(spacing: gap) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(Array(row.enumerated()), id: \.offset) { dayCell($0.element, cell) }
                }
            }
        }
    }

    private func glowRing(_ diameter: CGFloat, width: CGFloat, to fraction: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: width)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Self.cobalt, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Color(hex: 0x1F5FD6).opacity(0.8), radius: width * 0.5)
        }
        .frame(width: diameter, height: diameter)
    }

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
        case .weekGrid:
            dayGrid(["ddmd", "dddm", "ddtf"], cell: 132, gap: 24)
        case .ringDays:
            glowRing(640, width: 48, to: 0.78)
            dayGrid(["ddm", "ddd", "dtf"], cell: 96, gap: 18)
        case .hourglass:
            Image(systemName: "hourglass")
                .font(.system(size: 420, weight: .medium))
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0x9DB9FF)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: 0x1F5FD6).opacity(0.9), radius: 40)
        case .focusDial:
            ForEach([640.0, 460.0, 290.0], id: \.self) { d in
                Circle().stroke(.white.opacity(0.09), lineWidth: 6).frame(width: d, height: d)
            }
            glowRing(640, width: 46, to: 0.7)
            Circle().fill(Self.cobalt)
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .center), lineWidth: 5))
                .frame(width: 150, height: 150)
                .shadow(color: Color(hex: 0x1F5FD6).opacity(0.9), radius: 30)
        case .timeBlocks:
            VStack(alignment: .leading, spacing: 34) {
                timeBlock(Self.cobalt, 560)
                timeBlock(Self.cobalt, 400)
                timeBlock(Self.brick, 300)
                timeBlock(Self.graphite, 480)
            }
            .frame(width: 580, alignment: .leading)
        case .checkRing:
            glowRing(600, width: 54, to: 1)
            Image(systemName: "checkmark")
                .font(.system(size: 270, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
        case .railTrack:
            railTrack
        case .runningTrack:
            ForEach(0..<3, id: \.self) { lane in
                Capsule().stroke(.white.opacity(0.13), lineWidth: 20)
                    .frame(width: 640 - CGFloat(lane) * 90, height: 400 - CGFloat(lane) * 90)
            }
            Capsule()
                .trim(from: 0.05, to: 0.68)
                .stroke(Self.cobalt, style: StrokeStyle(lineWidth: 34, lineCap: .round))
                .frame(width: 640, height: 400)
                .shadow(color: Self.glow, radius: 22)
            Circle().fill(.white).frame(width: 64, height: 64)
                .shadow(color: Self.glow, radius: 16)
                .offset(x: -170, y: 200)
        case .milestonePath:
            milestonePath
        case .dayRing:
            let days = Array("ddddmdddmdtf")
            ForEach(days.indices, id: \.self) { i in
                let gap = 0.012
                Circle()
                    .trim(from: Double(i) / 12 + gap, to: Double(i + 1) / 12 - gap)
                    .stroke(dayStyle(days[i]), style: StrokeStyle(lineWidth: 78, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 560, height: 560)
                    .shadow(color: days[i] == "d" ? Self.glow.opacity(0.6) : .clear, radius: 14)
            }
            Image(systemName: "checkmark")
                .font(.system(size: 170, weight: .heavy))
                .foregroundStyle(.white)
        case .compass:
            Circle().stroke(.white.opacity(0.14), lineWidth: 10).frame(width: 600, height: 600)
            ForEach(0..<12, id: \.self) { i in
                Capsule().fill(.white.opacity(i % 3 == 0 ? 0.55 : 0.2))
                    .frame(width: 10, height: i % 3 == 0 ? 50 : 30)
                    .offset(y: -255)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            needle
                .rotationEffect(.degrees(28))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            Circle().fill(.white).frame(width: 56, height: 56)
        case .trendLine:
            trendLine
        case .dotGrid:
            let rows = ["ddmdddd", "dddmddd", "ddddddm", "dddddtf", "fffffff"]
            VStack(spacing: 22) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 22) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, kind in
                            Circle()
                                .fill(kind == "f" ? AnyShapeStyle(.white.opacity(0.08)) : dayStyle(kind))
                                .frame(width: 62, height: 62)
                                .shadow(color: kind == "d" ? Self.glow.opacity(0.5) : .clear, radius: 8)
                        }
                    }
                }
            }
        case .calendarCheck:
            calendarCheck
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

    private static let glow = Color(hex: 0x1F5FD6).opacity(0.85)

    private func dayStyle(_ kind: Character) -> AnyShapeStyle {
        switch kind {
        case "d": AnyShapeStyle(Self.cobalt)
        case "m": AnyShapeStyle(Self.brick)
        case "t": AnyShapeStyle(Self.graphite)
        default: AnyShapeStyle(.white.opacity(0.12))
        }
    }

    /// Two rails running into the distance; the sleepers are days: blue done, one red miss, grey ahead.
    private var railTrack: some View {
        let sleepers: [(y: CGFloat, kind: Character)] = [(850, "d"), (720, "d"), (610, "m"), (520, "d"), (445, "d"), (385, "t"), (335, "f")]
        func halfWidth(_ y: CGFloat) -> CGFloat { 60 + (y - 260) / (880 - 260) * 230 }
        return ZStack {
            ForEach(sleepers, id: \.y) { s in
                let w = halfWidth(s.y) * 2 + 70
                Capsule().fill(dayStyle(s.kind))
                    .frame(width: w, height: max(18, (s.y - 250) / 12))
                    .position(x: 512, y: s.y)
                    .shadow(color: s.kind == "d" ? Self.glow.opacity(0.6) : .clear, radius: 12)
            }
            ForEach([-1.0, 1.0], id: \.self) { side in
                Path { p in
                    p.move(to: CGPoint(x: 512 + side * halfWidth(905), y: 905))
                    p.addLine(to: CGPoint(x: 512 + side * halfWidth(260), y: 260))
                }
                .stroke(LinearGradient(colors: [.white, .white.opacity(0.35)], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round))
            }
        }
        .frame(width: 1024, height: 1024)
        .mask(tile.frame(width: 824, height: 824))
    }

    /// A winding path with checkpoints: done, done, missed, done, and today still ahead.
    private var milestonePath: some View {
        let points = [CGPoint(x: 290, y: 800), CGPoint(x: 470, y: 690), CGPoint(x: 380, y: 520),
                      CGPoint(x: 560, y: 410), CGPoint(x: 720, y: 280)]
        let kinds: [Character] = ["d", "d", "m", "d", "t"]
        return ZStack {
            Path { p in
                p.move(to: points[0])
                for i in 1..<points.count {
                    let a = points[i - 1], b = points[i]
                    p.addCurve(to: b, control1: CGPoint(x: a.x + 120, y: a.y - 20), control2: CGPoint(x: b.x - 120, y: b.y + 20))
                }
            }
            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 26, lineCap: .round, dash: [2, 44]))
            ForEach(points.indices, id: \.self) { i in
                Circle().fill(dayStyle(kinds[i]))
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 5))
                    .frame(width: i == points.count - 1 ? 120 : 92, height: i == points.count - 1 ? 120 : 92)
                    .position(points[i])
                    .shadow(color: kinds[i] == "d" ? Self.glow.opacity(0.7) : .clear, radius: 14)
            }
            Image(systemName: "flag.fill")
                .font(.system(size: 70, weight: .bold))
                .foregroundStyle(.white)
                .position(x: 728, y: 272)
        }
        .frame(width: 1024, height: 1024)
    }

    private var needle: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: -250)); p.addLine(to: CGPoint(x: 58, y: 0))
                p.addLine(to: CGPoint(x: -58, y: 0)); p.closeSubpath()
            }
            .fill(Self.cobalt)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 250)); p.addLine(to: CGPoint(x: 58, y: 0))
                p.addLine(to: CGPoint(x: -58, y: 0)); p.closeSubpath()
            }
            .fill(Self.brick)
        }
        .offset(x: 512, y: 512)
        .frame(width: 1024, height: 1024, alignment: .topLeading)
    }

    /// A rising line through the week, with one red dip it recovers from.
    private var trendLine: some View {
        let pts = [CGPoint(x: 230, y: 700), CGPoint(x: 340, y: 610), CGPoint(x: 450, y: 640),
                   CGPoint(x: 560, y: 500), CGPoint(x: 670, y: 560), CGPoint(x: 790, y: 330)]
        let kinds: [Character] = ["d", "d", "m", "d", "d", "d"]
        return ZStack {
            ForEach([380.0, 520.0, 660.0], id: \.self) { y in
                Capsule().fill(.white.opacity(0.07)).frame(width: 600, height: 6).position(x: 512, y: y)
            }
            Path { p in p.addLines(pts) }
                .stroke(Self.cobalt, style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
                .shadow(color: Self.glow, radius: 20)
            ForEach(pts.indices, id: \.self) { i in
                Circle().fill(kinds[i] == "m" ? AnyShapeStyle(Self.brick) : AnyShapeStyle(.white))
                    .frame(width: i == pts.count - 1 ? 84 : 58, height: i == pts.count - 1 ? 84 : 58)
                    .position(pts[i])
            }
        }
        .frame(width: 1024, height: 1024)
    }

    /// A calendar page whose days are colored, with today ticked off.
    private var calendarCheck: some View {
        let cells = Array("ddmddddmddddt")
        return VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(Self.cobalt)
                HStack(spacing: 170) {
                    ForEach(0..<2, id: \.self) { _ in Capsule().fill(.white.opacity(0.85)).frame(width: 26, height: 70) }
                }
                .offset(y: -6)
            }
            .frame(height: 130)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 16), count: 5), spacing: 16) {
                ForEach(cells.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(dayStyle(cells[i]))
                        .frame(width: 78, height: 62)
                }
            }
            .padding(.top, 34)
            Spacer(minLength: 0)
        }
        .frame(width: 520, height: 520)
        .background(Color(hex: 0x2A2A31))
        .clipShape(RoundedRectangle(cornerRadius: 70, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 70, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center), lineWidth: 4))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 190, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(hex: 0x0047AB))
                .shadow(color: Self.glow, radius: 20)
                .offset(x: 50, y: 50)
        }
    }

    private func timeBlock(_ fill: LinearGradient, _ width: CGFloat) -> some View {
        Capsule()
            .fill(fill)
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center), lineWidth: 3))
            .frame(width: width, height: 96)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
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
    static func renderSheet(_ styles: [IconStyle], to url: URL) {
        let cell: CGFloat = 300
        let rows = stride(from: 0, to: styles.count, by: 3).map { Array(styles[$0..<min($0 + 3, styles.count)]) }
        let sheet = VStack(spacing: 30) {
            ForEach(rows, id: \.self) { row in
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
                            Text("\((styles.firstIndex(of: style) ?? 0) + 1). \(style.title)")
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
                Text("On Track").font(.system(size: 15, weight: .medium))
                Spacer()
                AppIconView(style: style).scaleEffect(20 / 1024).frame(width: 20, height: 20)
                Text("On Track.app").font(.system(size: 13))
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
            .font(DigitFont.font(size, face: .compressed))
            .foregroundStyle(style)
            .overlay {
                Rectangle()
                    .frame(height: size * 0.03)
                    .offset(y: DigitFont.centerOffset(size, face: .compressed))
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}
