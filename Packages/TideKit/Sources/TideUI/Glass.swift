import SwiftUI

/// Little Tide's glass material: native Liquid Glass on iOS 26, a system material with a
/// rim highlight earlier, and an opaque surface when Reduce Transparency is on.
private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let isInteractive: Bool
    let tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Palette.paper, in: shape)
                .overlay(shape.strokeBorder(Palette.sand, lineWidth: 1))
        } else {
            glass(content)
                .overlay(rim)
                .shadow(color: Palette.glassShadow.opacity(colorScheme == .dark ? 0.45 : 0.16), radius: 18, x: 0, y: 10)
        }
    }

    @ViewBuilder
    private func glass(_ content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.glassEffect(Glass.regular.tint(tint).interactive(isInteractive), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .background((tint ?? .clear), in: shape)
        }
        #else
        content.background(.ultraThinMaterial, in: shape)
        #endif
    }

    /// A light rim: brighter on the upper-left edge where light enters, faint below.
    private var rim: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [.white.opacity(colorScheme == .dark ? 0.28 : 0.6), .white.opacity(0.05), .white.opacity(colorScheme == .dark ? 0.12 : 0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            lineWidth: 0.8
        )
        .allowsHitTesting(false)
    }
}

extension View {
    /// Places the view on Little Tide glass in `shape`.
    public func glassSurface<S: InsettableShape>(_ shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassSurface(shape: shape, isInteractive: interactive, tint: tint))
    }
}

/// A round or capsule glass button with a gentle pressed state.
public struct GlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassSurface(Capsule(), interactive: true)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
