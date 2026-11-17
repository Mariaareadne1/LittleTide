import Foundation

/// The tide compositing rule, mirrored exactly by `TideScene.metal`.
enum Composite {
    /// Normalised tide 0…1 maps to this height band.
    static let levelRange: ClosedRange<Float> = 0.455...0.545
    /// height.png stores (h − heightMin) / heightSpan.
    static let heightMin: Float = 0.05
    static let heightSpan: Float = 0.75

    static func level(_ t: Float) -> Float { levelRange.lowerBound + (levelRange.upperBound - levelRange.lowerBound) * t }

    static func pixel(level L: Float, h: Float, land: RGB, water: RGB, foamLace: Float, wander: Float, spec: SceneSpec) -> RGB {
        let depth = L - h
        var col: RGB
        if depth <= 0 {
            let wet = 1 - smoothstep(0, 0.016, -depth)
            col = land.scaled(1 - spec.wetDarkening * wet)
            col = col.mix(spec.turquoise.mix(land, 0.5), 0.14 * wet)
        } else {
            let deep = smoothstep(0.02, 0.32, depth)
            let seabed = land * spec.seabedTint
            let shallow = seabed.mix(spec.turquoise, 0.38)
            col = shallow.mix(water, deep)
        }
        // Surf: solid ribbons whose edges break into lace. Ribbons wander off the depth
        // contours (`wander`), and the lace perturbs the threshold so cores stay opaque.
        let d = depth + wander * 0.04
        // The edge band stops at the waterline: no foam on dry sand.
        let edge = exp(-pow((depth - 0.006) / 0.02, 2)) * smoothstep(-0.008, 0.002, depth)
        let band1 = exp(-pow((d - 0.05) / 0.022, 2)) * 0.95
        let band2 = exp(-pow((d - 0.105) / 0.02, 2)) * 0.8
        let band3 = exp(-pow((d - 0.16) / 0.012, 2)) * 0.5
        // Surf only breaks in shallow water.
        let shallowGate = 1 - smoothstep(0.17, 0.21, depth)
        let band = max(max(edge, band1), max(band2, band3)) * shallowGate
        let threshold = 0.42 + (0.5 - foamLace) * 0.5
        let foam = smoothstep(threshold - 0.07, threshold + 0.07, band)
        let wash = band * foamLace * 0.3 * smoothstep(-0.004, 0.004, depth)
        return col.mix(spec.foam, clamp01(foam * 0.97 + wash))
    }
}
