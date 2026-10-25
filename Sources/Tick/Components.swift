import SwiftUI

/// Countdown digits with a thin background-colored line cut through their middle.
/// Shrinks to fit `maxWidth` and centers on the digits themselves, so any ClockFont sits right in the ring.
struct SplitDigits: View {
    let minutes: String
    let seconds: String
    let size: CGFloat
    let color: Color
    let gapColor: Color
    var maxWidth: CGFloat = .infinity
    var face: ClockFont = DigitFont.face

    var body: some View {
        let size = DigitFont.fitting(self.size, width: maxWidth, face: face)
        let center = DigitFont.centerOffset(size, face: face)
        HStack(spacing: size * 0.14) {
            Text(minutes)
            Text(seconds)
        }
        .font(DigitFont.font(size, face: face))
        .monospacedDigit()
        .foregroundStyle(color)
        .fixedSize()
        .overlay {
            Rectangle()
                .fill(gapColor)
                .frame(height: max(2, size * 0.045))
                .offset(y: center)
        }
        .offset(y: -center)
    }
}

/// Gray track with a blue fill up to the thumb.
struct BlueSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double?
    var dimmed = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        let fill = dimmed ? p.muted : p.accent
        GeometryReader { geo in
            let usable = max(geo.size.width - 16, 1)
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let x = fraction * usable
            ZStack(alignment: .leading) {
                Capsule().fill(p.sliderTrack).frame(height: 6)
                Capsule().fill(fill).frame(width: x + 8, height: 6)
                Circle()
                    .fill(fill)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let f = min(max((drag.location.x - 8) / usable, 0), 1)
                var newValue = range.lowerBound + f * (range.upperBound - range.lowerBound)
                if let step { newValue = (newValue / step).rounded() * step }
                if newValue != value { value = newValue }
            })
        }
        .frame(height: 18)
    }
}

struct BlueSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        SwitchRow(configuration: configuration)
    }

    private struct SwitchRow: View {
        let configuration: ToggleStyleConfiguration
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            let p = Palette.of(scheme)
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? p.accent : p.sliderTrack)
                    .frame(width: 32, height: 18)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 14, height: 14).padding(2)
                    }
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() }
                    }
            }
        }
    }
}

struct Segmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    selection = value
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selection == value ? p.onAccent : p.text)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(selection == value ? p.accent : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(p.tonal, in: RoundedRectangle(cornerRadius: 9))
    }
}

/// White rounded box used to group settings rows.
struct Box<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        VStack(alignment: .leading, spacing: 10) { content }
            .font(.system(size: 12))
            .foregroundStyle(p.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 0.5))
    }
}

struct TabTitle: View {
    let text: String
    var color: Color?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(color ?? Palette.of(scheme).accent)
            .frame(maxWidth: .infinity)
    }
}

/// Scrolls in the app. ImageRenderer can't draw ScrollView contents, so snapshots lay it out flat.
struct PanelScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if Snapshot.isRendering {
            content
        } else {
            ScrollView { content }.scrollIndicators(.never)
        }
    }
}
