import SwiftUI

/// The countdown pill shown in the menu bar, rendered to a (non-template) image so it keeps its color.
enum MenuBarPill {
    @MainActor
    static func image(minutes: String, seconds: String, phase: Phase, running: Bool, fresh: Bool) -> NSImage {
        let p = Palette.light
        let color = p.accent(for: phase)
        let icon = !running && !fresh ? "pause.fill" : (phase.isBreak ? "cup.and.saucer.fill" : "target")
        let pill = HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text("\(minutes) \(seconds)")
                .font(DigitFont.font(15))
                .monospacedDigit()
        }
        .foregroundStyle(p.onAccent)
        .padding(.horizontal, 7)
        .frame(height: 18)
        .background(Capsule().fill(color))

        let renderer = ImageRenderer(content: pill)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return NSImage() }
        let image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
        image.isTemplate = false
        return image
    }
}
