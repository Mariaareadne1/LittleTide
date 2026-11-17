import SwiftUI

/// Collects liquid-glass panel frames inside a glass stage.
public struct GlassPanelsKey: PreferenceKey {
    public static let defaultValue: [GlassPanel] = []
    public static func reduce(value: inout [GlassPanel], nextValue: () -> [GlassPanel]) { value.append(contentsOf: nextValue()) }
}

extension EnvironmentValues {
    /// Name of the coordinate space of the enclosing glass stage, when there is one.
    @Entry public var glassStage: String? = nil
}

/// A panel of liquid glass. Inside a glass stage (a `PaintedCoastView` that receives the
/// collected frames) the shader renders the glass, so it genuinely refracts the painting
/// beneath it. Elsewhere it falls back to system glass; under Reduce Transparency it is an
/// opaque deep-teal surface.
private struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let kind: GlassPanel.Kind
    @Environment(\.glassStage) private var stage
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(Palette.oceanDeep, in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
        } else if let stage {
            content
                .contentShape(shape)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: GlassPanelsKey.self,
                                               value: [GlassPanel(frame: proxy.frame(in: .named(stage)), cornerRadius: cornerRadius, kind: kind)])
                    }
                )
        } else {
            content.glassSurface(shape, tint: Palette.oceanDeep.opacity(0.82))
        }
    }
}

extension View {
    /// Renders this view's background as liquid glass (see `LiquidGlassModifier`).
    /// Use a large `cornerRadius` for capsules; the shader clamps it to the half-height.
    public func liquidGlass(cornerRadius: CGFloat, kind: GlassPanel.Kind = .card) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, kind: kind))
    }

    /// Makes this view a glass stage: descendants marked `liquidGlass` are reported in its
    /// coordinate space through `onPanels`, for a `PaintedCoastView` drawn at the same frame.
    public func glassStage(_ name: String, onPanels: @escaping ([GlassPanel]) -> Void) -> some View {
        self
            .environment(\.glassStage, name)
            .coordinateSpace(name: name)
            .onPreferenceChange(GlassPanelsKey.self) { onPanels($0) }
    }
}

/// A round or capsule liquid-glass button: the glass is optical, the press is a soft glow.
public struct LiquidGlassButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0))
            )
            .liquidGlass(cornerRadius: 999, kind: .button)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
