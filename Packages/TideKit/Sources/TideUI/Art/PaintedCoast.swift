import SwiftUI
import TideKit
#if canImport(UIKit)
import UIKit
#endif

/// A layered, painted coast rendered by ArtForge (see `Sources/ArtForge`).
public enum PaintedScene: String, CaseIterable, Sendable {
    case eastCoast

    /// Scene parameters that the shader needs (mirrors `SceneSpec`).
    struct Look {
        let turquoise: SIMD3<Float>, seabedTint: SIMD3<Float>, foam: SIMD3<Float>
        let wetDarkening: Float
        let aspect: Float
    }

    var look: Look {
        switch self {
        case .eastCoast:
            return Look(turquoise: rgb(0x8EDDD1), seabedTint: rgb(0xA6DCD2), foam: rgb(0xF7F6EE), wetDarkening: 0.3, aspect: 1080 / 2340)
        }
    }

    /// The painted scene for a coast region, when one exists yet.
    public init?(region: CoastRegion) {
        switch region {
        case .northAtlantic: self = .eastCoast
        default: return nil
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
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Scenes/\(scene)"),
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

/// The painted coast at a normalised tide level (0 = lowest, 1 = highest in view).
/// Illustrative only: the waterline is not a map of the station's real shoreline.
public struct PaintedCoastView: View {
    let scene: PaintedScene
    let level: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(scene: PaintedScene, level: Double) {
        self.scene = scene
        self.level = level
    }

    public var body: some View {
        #if canImport(UIKit)
        if let atlas = LayerCache.shared.atlas(scene: scene.rawValue) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let time = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                Rectangle()
                    .visualEffect { content, proxy in
                        content.colorEffect(shader(size: proxy.size, time: time, atlas: Image(uiImage: atlas)))
                    }
            }
            .accessibilityElement()
            .accessibilityLabel("Illustration of a coast from above. Representative, not a live view.")
            .accessibilityAddTraits(.isImage)
        } else {
            Color(red: 0.08, green: 0.36, blue: 0.43)
        }
        #else
        Color.teal
        #endif
    }

    private func shader(size: CGSize, time: Float, atlas: Image) -> Shader {
        let look = scene.look
        return ShaderLibrary.bundle(.module).tideScene(
            .float2(size), .float(look.aspect), .float(PaintedScene.level(level)), .float(time), .float(reduceMotion ? 0 : 1),
            .image(atlas),
            .float3(look.turquoise.x, look.turquoise.y, look.turquoise.z),
            .float3(look.seabedTint.x, look.seabedTint.y, look.seabedTint.z),
            .float3(look.foam.x, look.foam.y, look.foam.z),
            .float(look.wetDarkening)
        )
    }
}
