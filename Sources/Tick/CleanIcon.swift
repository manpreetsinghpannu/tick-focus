import SwiftUI

/// Flat, geometric app-icon marks: one ink color on a plain tile, with Cobalt as the single accent.
enum CleanMark: String, CaseIterable {
    case halftone, lanes, stripes, chevrons, converge, dial, pixelCheck, pie, orbit

    var title: String {
        switch self {
        case .halftone: "Halftone"
        case .lanes: "Lanes"
        case .stripes: "Stripes"
        case .chevrons: "Chevrons"
        case .converge: "Converge"
        case .dial: "Dial"
        case .pixelCheck: "Pixel check"
        case .pie: "Pie"
        case .orbit: "Orbit"
        }
    }
}

struct CleanIconView: View {
    let mark: CleanMark
    var dark = false

    private var ink: Color { dark ? Color(hex: 0xF2EFE8) : Color(hex: 0x141414) }
    private var paper: Color { dark ? Color(hex: 0x17171A) : Color(hex: 0xF2EFE8) }
    private var accent: Color { dark ? Color(hex: 0x2F6BFF) : Color(hex: 0x0047AB) }
    private let tile = RoundedRectangle(cornerRadius: 185, style: .continuous)

    var body: some View {
        ZStack {
            tile.fill(paper)
                .overlay(tile.strokeBorder(ink.opacity(dark ? 0.12 : 0.08), lineWidth: 3))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            artwork
        }
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder private var artwork: some View {
        switch mark {
        case .halftone: halftone
        case .lanes: lanes
        case .stripes: stripes
        case .chevrons: chevrons
        case .converge: converge
        case .dial: dial
        case .pixelCheck: pixelCheck
        case .pie: pie
        case .orbit: orbit
        }
    }

    /// A disc of dots that grow from left to right: progress building up.
    private var halftone: some View {
        ZStack {
            ForEach(-4...4, id: \.self) { i in
                ForEach(-4...4, id: \.self) { j in
                    let x = CGFloat(i) * 66, y = CGFloat(j) * 66
                    if (x * x + y * y).squareRoot() <= 290 {
                        let size = 12 + CGFloat(i + 4) / 8 * 46
                        Circle().fill(i == 4 ? accent : ink)
                            .frame(width: size, height: size)
                            .offset(x: x, y: y)
                    }
                }
            }
        }
    }

    /// Concentric running lanes, each with the same gap, and a runner on the outside lane.
    private var lanes: some View {
        ZStack {
            ForEach([600.0, 450.0, 300.0], id: \.self) { d in
                Circle()
                    .trim(from: 0, to: 0.78)
                    .stroke(ink, style: StrokeStyle(lineWidth: 44, lineCap: .round))
                    .rotationEffect(.degrees(-50))
                    .frame(width: d, height: d)
            }
            Circle().fill(accent).frame(width: 120, height: 120)
        }
    }

    /// Op-art disc: stripes that thicken toward the bottom, the last one in Cobalt.
    private var stripes: some View {
        VStack(spacing: 18) {
            ForEach(0..<8, id: \.self) { i in
                Rectangle().fill(i == 7 ? accent : ink).frame(height: 10 + CGFloat(i) * 8)
            }
        }
        .frame(width: 600)
        .mask(Circle().frame(width: 600, height: 600))
    }

    /// Two forward chevrons: keep moving.
    private var chevrons: some View {
        HStack(spacing: -40) {
            chevron(ink)
            chevron(accent)
        }
        .offset(x: 30)
    }

    private func chevron(_ color: Color) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 170, y: 190))
            p.addLine(to: CGPoint(x: 0, y: 380))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 96, lineCap: .square, lineJoin: .miter))
        .frame(width: 230, height: 380)
    }

    /// Lines running into one point on the horizon, like rails seen head-on.
    private var converge: some View {
        let vanishing = CGPoint(x: 512, y: 250)
        return ZStack {
            ForEach(0..<11, id: \.self) { i in
                let x = 210 + CGFloat(i) * 60.4
                Path { p in
                    p.move(to: CGPoint(x: x, y: 800))
                    p.addLine(to: vanishing)
                }
                .stroke(i == 5 ? accent : ink, style: StrokeStyle(lineWidth: i == 5 ? 26 : 16, lineCap: .round))
            }
            Rectangle().fill(ink).frame(width: 640, height: 22).position(x: 512, y: 800)
        }
        .frame(width: 1024, height: 1024)
    }

    /// Clock-like ring of bars; the last quarter fades out, like time still left.
    private var dial: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(i < 18 ? ink : ink.opacity(0.18))
                    .frame(width: 26, height: 110)
                    .offset(y: -240)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
            Circle().fill(accent).frame(width: 150, height: 150)
        }
    }

    /// A checkmark built from grid squares.
    private var pixelCheck: some View {
        // [column, row]: an even, two-cell-thick check, centered in the 7×7 grid.
        let on: Set<[Int]> = [[5, 1], [6, 1], [4, 2], [5, 2],
                              [0, 3], [1, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4], [2, 5]]
        return VStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(on.contains([col, row]) ? (row <= 2 ? accent : ink) : ink.opacity(0.08))
                            .frame(width: 66, height: 66)
                    }
                }
            }
        }
    }

    /// A timer pie with its last quarter lifted out in Cobalt.
    private var pie: some View {
        ZStack {
            Wedge(start: .degrees(0), end: .degrees(270)).fill(ink)
                .frame(width: 560, height: 560)
            Wedge(start: .degrees(270), end: .degrees(360)).fill(accent)
                .frame(width: 560, height: 560)
                .offset(x: 28, y: -28)
        }
    }

    /// A ring with a solid core and a Cobalt marker on its path.
    private var orbit: some View {
        ZStack {
            Circle().stroke(ink, lineWidth: 40).frame(width: 560, height: 560)
            Circle().fill(ink).frame(width: 190, height: 190)
            Circle().fill(accent)
                .overlay(Circle().strokeBorder(paper, lineWidth: 18))
                .frame(width: 150, height: 150)
                .offset(x: 198, y: -198)
        }
    }

    // MARK: Rendering

    @MainActor
    static func render(_ mark: CleanMark, dark: Bool, to url: URL) {
        write(CleanIconView(mark: mark, dark: dark), scale: 1, to: url)
    }

    /// Every mark on a light and a dark tile, three per row.
    @MainActor
    static func renderSheet(to url: URL) {
        let marks = CleanMark.allCases
        let rows = stride(from: 0, to: marks.count, by: 3).map { Array(marks[$0..<min($0 + 3, marks.count)]) }
        let sheet = VStack(spacing: 30) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 34) {
                    ForEach(row, id: \.self) { mark in
                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                CleanIconView(mark: mark).scaleEffect(240 / 1024).frame(width: 240, height: 240)
                                CleanIconView(mark: mark, dark: true).scaleEffect(240 / 1024).frame(width: 240, height: 240)
                            }
                            HStack(spacing: 12) {
                                CleanIconView(mark: mark).scaleEffect(64 / 1024).frame(width: 64, height: 64)
                                CleanIconView(mark: mark, dark: true).scaleEffect(64 / 1024).frame(width: 64, height: 64)
                                CleanIconView(mark: mark).scaleEffect(32 / 1024).frame(width: 32, height: 32)
                                CleanIconView(mark: mark, dark: true).scaleEffect(32 / 1024).frame(width: 32, height: 32)
                            }
                            Text("\((marks.firstIndex(of: mark) ?? 0) + 1). \(mark.title)")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x141414))
                        }
                    }
                }
            }
        }
        .padding(40)
        .background(Color(hex: 0xDCD8CF))
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

/// A pie slice measured clockwise from 12 o'clock.
private struct Wedge: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                 startAngle: start - .degrees(90), endAngle: end - .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}
