import SwiftUI
import TideKit

/// Original, procedurally painted coastal illustration, representative of a kind of
/// coast and never a specific beach. `waterLevel` (0 = lowest, 1 = highest predicted
/// water in the viewed window) moves the water's edge along a fixed, abstract beach.
public struct CoastArtView: View {
    public enum Style: Sendable {
        /// Full-colour painted layers.
        case painted
        /// Single-colour line drawing, for tinted/clear widget rendering.
        case line
    }

    let region: CoastRegion
    let waterLevel: Double
    let style: Style
    let horizon: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameter horizon: fraction of the height above the horizon (more sky leaves room
    ///   for titles set over the picture).
    public init(region: CoastRegion, waterLevel: Double = 0.5, style: Style = .painted, horizon: CGFloat = 0.5) {
        self.region = region
        self.waterLevel = min(max(waterLevel, 0), 1)
        self.style = style
        self.horizon = min(max(horizon, 0.25), 0.75)
    }

    public var body: some View {
        Group {
            switch style {
            case .painted:
                let palette = ArtPalette.make(region, dusk: colorScheme == .dark)
                ZStack {
                    // Static layers are rasterised once and reused while the tide moves.
                    Canvas { context, size in
                        CoastBackdropPainter(scene: scene(size, level: 0.5), palette: palette).paint(&context)
                    }
                    .drawingGroup()
                    Canvas { context, size in
                        let scene = scene(size, level: waterLevel)
                        CoastShorePainter(scene: scene, palette: palette).paint(&context)
                        GrainPainter(scene: scene, palette: palette).paint(&context)
                    }
                    .drawingGroup()
                }
            case .line:
                Canvas { context, size in
                    CoastLinePainter(scene: scene(size, level: waterLevel)).paint(&context)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Illustration: \(region.illustrationDescription). Representative, not a live view.")
        .accessibilityAddTraits(.isImage)
    }

    private func scene(_ size: CGSize, level: Double) -> CoastScene {
        CoastScene(region: region, size: size, waterLevel: level, horizon: horizon)
    }
}

#Preview("Regions") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(CoastRegion.allCases, id: \.self) { region in
                CoastArtView(region: region, waterLevel: 0.35).aspectRatio(4 / 3, contentMode: .fit)
            }
        }
        .padding()
    }
}
