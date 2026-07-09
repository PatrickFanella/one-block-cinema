import SwiftUI

struct FilmGrainView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    var body: some View {
        if !reduceTransparency {
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height * 0.003) {
                    let x = Double.random(in: 0...size.width)
                    let y = Double.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.02...0.08)
                    let dotSize = Double.random(in: 0.5...1.5)
                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                        with: .color(.white)
                    )
                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }
}
