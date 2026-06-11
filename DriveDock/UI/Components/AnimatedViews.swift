import SwiftUI

struct AnimatedProgressView: View {
    let progress: Double
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: Double, color: Color = .accentColor) {
        self.progress = progress
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }
}

struct PulsingDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.6)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
            .accessibilityHidden(true)
    }
}

struct SmoothCounter: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    displayValue = newValue
                }
            }
            .accessibilityLabel("\(value)")
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: Color.primary.opacity(0.05), radius: 4, y: 2)
    }
}

struct FadeInView<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: isVisible)
            .onAppear { isVisible = true }
    }
}
