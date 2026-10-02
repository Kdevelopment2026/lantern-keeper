import SwiftUI

/// Decorative lighthouse. Hidden from accessibility: the containing screen exposes the
/// state through `WatchStatusLabel`.
struct LighthouseScene: View {
    let state: LighthouseSceneState
    var frame: LighthouseFrame?
    var highContrast = false

    var body: some View {
        let drawing = LighthouseDrawing(
            state: state,
            frame: frame ?? .resting(for: state),
            highContrast: highContrast
        )
        Canvas(opaque: true) { context, size in
            drawing.draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    LighthouseScene(state: .watching(progress: 0.3))
        .ignoresSafeArea()
}
