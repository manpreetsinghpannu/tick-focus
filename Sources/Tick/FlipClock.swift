import SwiftUI

/// One split-flap card. On change, the old top half folds down (darkening as it turns),
/// then the new bottom half swings into place.
struct FlipDigit: View {
    let digit: Character
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let card: Color
    let gap: Color

    @State private var current: Character = " "
    @State private var previous: Character = " "
    @State private var topAngle = 0.0
    @State private var bottomAngle = 90.0

    private let halfDuration = 0.17

    var body: some View {
        ZStack {
            half(current, top: true)
            half(previous, top: false)
            half(previous, top: true)
                .brightness(-0.35 * abs(topAngle) / 90)
                .rotation3DEffect(.degrees(topAngle), axis: (1, 0, 0), anchor: .bottom, perspective: 0.45)
                .frame(width: width, height: height, alignment: .top)
            half(current, top: false)
                .brightness(-0.35 * abs(bottomAngle) / 90)
                .rotation3DEffect(.degrees(bottomAngle), axis: (1, 0, 0), anchor: .top, perspective: 0.45)
                .frame(width: width, height: height, alignment: .bottom)
                .opacity(bottomAngle >= 89.9 ? 0 : 1)
            Rectangle()
                .fill(gap)
                .frame(width: width, height: max(2, height * 0.018))
        }
        .frame(width: width, height: height)
        .onAppear {
            current = digit
            previous = digit
        }
        .onChange(of: digit) { _, new in flip(to: new) }
    }

    private func half(_ character: Character, top: Bool) -> some View {
        let fontSize = height * 1.12
        let radius = width * 0.1
        return Text(String(character))
            .font(DigitFont.font(fontSize))
            .foregroundStyle(color)
            .frame(width: width, height: height)
            .offset(y: -DigitFont.centerOffset(fontSize))
            .frame(width: width, height: height / 2, alignment: top ? .top : .bottom)
            .clipped()
            .background(card, in: UnevenRoundedRectangle(
                topLeadingRadius: top ? radius : 0, bottomLeadingRadius: top ? 0 : radius,
                bottomTrailingRadius: top ? 0 : radius, topTrailingRadius: top ? radius : 0))
            .frame(width: width, height: height, alignment: top ? .top : .bottom)
    }

    private func flip(to new: Character) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            previous = current
            current = new
            topAngle = 0
            bottomAngle = 90
        }
        withAnimation(.easeIn(duration: halfDuration)) {
            topAngle = -90
        } completion: {
            withAnimation(.easeOut(duration: halfDuration)) {
                bottomAngle = 0
            } completion: {
                withTransaction(instant) { previous = current }
            }
        }
    }
}

/// The big focus window: four flip cards that scale with the window, plus play/pause and reset.
struct FlipClockView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        let accent = p.accent(for: engine.phase)
        GeometryReader { geo in
            let cardHeight = min(geo.size.height * 0.56, geo.size.width / 4.2)
            let cardWidth = cardHeight * 0.64
            let digits = Array(engine.minutesText + engine.secondsText)

            VStack(spacing: cardHeight * 0.1) {
                HStack(spacing: cardHeight * 0.18) {
                    HStack(spacing: cardWidth * 0.04) {
                        card(digits[0], cardWidth, cardHeight, accent, p)
                        card(digits[1], cardWidth, cardHeight, accent, p)
                    }
                    HStack(spacing: cardWidth * 0.04) {
                        card(digits[2], cardWidth, cardHeight, accent, p)
                        card(digits[3], cardWidth, cardHeight, accent, p)
                    }
                }
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(p.muted)
                HStack(spacing: 18) {
                    Button(action: engine.toggle) {
                        Image(systemName: engine.isRunning ? "pause" : "play")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    .help(engine.isRunning ? "Pause (space)" : "Start (space)")
                    Button(action: engine.reset) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reset")
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(p.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(p.flipBg)
        .frame(minWidth: 420, minHeight: 240)
    }

    private var caption: String {
        var parts = [engine.mode == .pomodoro && !engine.phase.isBreak
            ? "Focus · round \(engine.round) of \(settings.rounds)"
            : engine.phase.title]
        let label = engine.workingOnTitle
        if !label.isEmpty && !engine.phase.isBreak { parts.append(label) }
        return parts.joined(separator: " · ")
    }

    private func card(_ d: Character, _ w: CGFloat, _ h: CGFloat, _ color: Color, _ p: Palette) -> some View {
        FlipDigit(digit: d, width: w, height: h, color: color, card: p.flipCard, gap: p.flipBg)
    }
}
