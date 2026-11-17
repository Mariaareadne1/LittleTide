import SwiftUI
import TideKit
#if canImport(UIKit)
import UIKit
#endif

/// A layered, painted coast rendered by ArtForge (see `Sources/ArtForge`).
public enum PaintedScene: String, CaseIterable, Sendable {
    case eastCoast
    case norCal
    case soCal

    /// Scene parameters that the shader needs (mirrors `SceneSpec`).
    struct Look: Sendable {
        let turquoise: SIMD3<Float>, seabedTint: SIMD3<Float>, foam: SIMD3<Float>
        let wetDarkening: Float
        let aspect: Float
    }

    var look: Look {
        switch self {
        case .eastCoast:
            return Look(turquoise: rgb(0x8EDDD1), seabedTint: rgb(0xA6DCD2), foam: rgb(0xF7F6EE), wetDarkening: 0.3, aspect: 1080 / 2340)
        case .norCal:
            return Look(turquoise: rgb(0x79C4BC), seabedTint: rgb(0x8FC2BC), foam: rgb(0xF2F4F0), wetDarkening: 0.34, aspect: 1080 / 2340)
        case .soCal:
            return Look(turquoise: rgb(0x9BE6D7), seabedTint: rgb(0xB2E6D9), foam: rgb(0xFBF9F1), wetDarkening: 0.26, aspect: 1080 / 2340)
        }
    }

    /// The representative painted scene for a coast region. Scenes are generic coasts of a
    /// kind, never the station's actual shoreline:
    /// - Atlantic, marsh and Gulf coasts → pale sand, dunes, shallow surf (`eastCoast`)
    /// - Northern California / Pacific Northwest / Alaska → dark rocky cove, kelp (`norCal`)
    /// - Southern California / tropical islands → warm sand, turquoise water, reefs (`soCal`)
    public init?(region: CoastRegion) {
        switch region {
        case .northAtlantic, .southAtlanticMarsh, .gulfShore: self = .eastCoast
        case .northernPacific, .northernFjord: self = .norCal
        case .southernCalifornia, .tropicalIsland: self = .soCal
        }
    }

    /// Plain-language name used in captions and VoiceOver.
    public var caption: String {
        switch self {
        case .eastCoast: return "Atlantic coast with dunes and sandbars"
        case .norCal: return "Rocky Pacific cove with kelp"
        case .soCal: return "Warm-sand beach with reefs"
        }
    }

    public static let levelRange: ClosedRange<Float> = 0.455...0.545

    public static func level(_ normalized: Double) -> Float {
        levelRange.lowerBound + (levelRange.upperBound - levelRange.lowerBound) * Float(min(max(normalized, 0), 1))
    }

    /// Precomputed widget snapshot nearest to `normalized` level (WidgetKit can't run shaders).
    public func widgetImage(family: CoastWidgetBackground.Family, level normalized: Double) -> Image? {
        let step = Int((min(max(normalized, 0), 1) * 4).rounded())
        return Self.image("widget-\(family == .small ? "small" : "medium")-\(step)", ext: "jpg", scene: self)
    }

    /// Painted water with no people or boats, for filling under the tide curve.
    public var chartFill: Image? { Self.image("chart-fill", ext: "jpg", scene: self) }

    static func image(_ name: String, ext: String, scene: PaintedScene) -> Image? {
        #if canImport(UIKit)
        guard let ui = LayerCache.shared.image(named: name, ext: ext, scene: scene.rawValue) else { return nil }
        return Image(uiImage: ui)
        #else
        return nil
        #endif
    }

    private func rgb(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(Float((hex >> 16) & 0xFF) / 255, Float((hex >> 8) & 0xFF) / 255, Float(hex & 0xFF) / 255)
    }
}

#if canImport(UIKit)
/// Decoded layer images, kept for the life of the process.
final class LayerCache: @unchecked Sendable {
    static let shared = LayerCache()
    private let lock = NSLock()
    private var images: [String: UIImage] = [:]

    func image(named name: String, ext: String, scene: String) -> UIImage? {
        let key = "\(scene)/\(name).\(ext)"
        lock.lock(); defer { lock.unlock() }
        if let cached = images[key] { return cached }
        // Full-size layers live in the app bundle; widget snapshots in TideUI's bundle.
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Scenes/\(scene)")
                ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Scenes/\(scene)"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        images[key] = image
        return image
    }

    /// land | water | data panels in one image, built once per scene.
    func atlas(scene: String) -> UIImage? {
        let key = "\(scene)/atlas"
        lock.lock()
        if let cached = images[key] { lock.unlock(); return cached }
        lock.unlock()
        guard let land = image(named: "land", ext: "jpg", scene: scene),
              let water = image(named: "water", ext: "jpg", scene: scene),
              let data = image(named: "data", ext: "png", scene: scene) else { return nil }
        let panel = land.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let atlas = UIGraphicsImageRenderer(size: CGSize(width: panel.width * 3, height: panel.height), format: format).image { _ in
            land.draw(in: CGRect(origin: .zero, size: panel))
            water.draw(in: CGRect(x: panel.width, y: 0, width: panel.width, height: panel.height))
            data.draw(in: CGRect(x: panel.width * 2, y: 0, width: panel.width, height: panel.height))
        }
        lock.lock(); images[key] = atlas; lock.unlock()
        return atlas
    }
}
#endif

/// A liquid-glass panel rendered by the scene shader (so it refracts the painting).
public struct GlassPanel: Equatable, Sendable {
    public enum Kind: Float, Sendable { case card = 0, button = 1 }
    public var frame: CGRect
    public var cornerRadius: CGFloat
    public var kind: Kind

    public init(frame: CGRect, cornerRadius: CGFloat, kind: Kind) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.kind = kind
    }
}

/// Legibility scrims baked into the scene, so glass refracts them instead of being dimmed.
public struct SceneScrim: Equatable, Sendable {
    public var topEnd: CGFloat
    public var bottomStart: CGFloat
    public var topAlpha: Float
    public var bottomAlpha: Float

    public static let none = SceneScrim(topEnd: 1, bottomStart: 100_000, topAlpha: 0, bottomAlpha: 0)

    public init(topEnd: CGFloat, bottomStart: CGFloat, topAlpha: Float, bottomAlpha: Float) {
        self.topEnd = topEnd
        self.bottomStart = bottomStart
        self.topAlpha = topAlpha
        self.bottomAlpha = bottomAlpha
    }
}

/// The painted coast at a normalised tide level (0 = lowest, 1 = highest in view).
/// Illustrative only: the waterline is not a map of the station's real shoreline.
public struct PaintedCoastView: View {
    public enum Mode: Sendable { case coast, underwater }

    let scene: PaintedScene
    let level: Double
    let mode: Mode
    let scrim: SceneScrim
    let panels: [GlassPanel]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(scene: PaintedScene, level: Double, mode: Mode = .coast, scrim: SceneScrim = .none, panels: [GlassPanel] = []) {
        self.scene = scene
        self.level = level
        self.mode = mode
        self.scrim = scrim
        self.panels = panels
    }

    public var body: some View {
        #if canImport(UIKit)
        if let atlas = LayerCache.shared.atlas(scene: scene.rawValue) {
            let look = scene.look
            let level = PaintedScene.level(level)
            let motion: Float = reduceMotion ? 0 : 1
            let image = Image(uiImage: atlas)
            let underwater: Float = mode == .underwater ? 1 : 0
            let scrim = scrim
            // Under Reduce Transparency the glass is drawn as opaque surfaces by SwiftUI instead.
            let panelData = reduceTransparency ? [Float(0)] : Self.encode(panels)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let time = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                Rectangle()
                    .visualEffect { content, proxy in
                        content.colorEffect(Self.shader(look: look, size: proxy.size, level: level, time: time, motion: motion, atlas: image,
                                                        underwater: underwater, scrim: scrim, panels: panelData))
                    }
            }
            .accessibilityElement()
            .accessibilityLabel("Illustration: \(scene.caption), seen from above. Representative, not a live view.")
            .accessibilityAddTraits(.isImage)
        } else {
            Color(red: 0.08, green: 0.36, blue: 0.43)
        }
        #else
        Color.teal
        #endif
    }

    /// Pure, so it can be built inside SwiftUI's nonisolated `visualEffect` closure.
    static func encode(_ panels: [GlassPanel]) -> [Float] {
        var data: [Float] = [Float(min(panels.count, 8))]
        for panel in panels.prefix(8) {
            data += [Float(panel.frame.midX), Float(panel.frame.midY), Float(panel.frame.width / 2), Float(panel.frame.height / 2),
                     Float(panel.cornerRadius), panel.kind.rawValue, 0, 0]
        }
        return data
    }

    private nonisolated static func shader(look: PaintedScene.Look, size: CGSize, level: Float, time: Float, motion: Float, atlas: Image,
                                           underwater: Float, scrim: SceneScrim, panels: [Float]) -> Shader {
        ShaderLibrary.bundle(.module).tideScene(
            .float2(size), .float(look.aspect), .float(level), .float(time), .float(motion),
            .image(atlas),
            .float3(look.turquoise.x, look.turquoise.y, look.turquoise.z),
            .float3(look.seabedTint.x, look.seabedTint.y, look.seabedTint.z),
            .float3(look.foam.x, look.foam.y, look.foam.z),
            .float(look.wetDarkening),
            .float(underwater),
            .float4(Float(scrim.topEnd), Float(scrim.bottomStart), scrim.topAlpha, scrim.bottomAlpha),
            .floatArray(panels)
        )
    }
}
