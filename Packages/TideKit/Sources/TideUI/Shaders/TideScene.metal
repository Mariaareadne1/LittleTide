#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Mirrors ArtForge/Composite.swift. Keep the constants in sync.
constant float kHeightMin = 0.05;
constant float kHeightSpan = 0.75;

static float sstep(float a, float b, float x) {
    float t = clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

static float gauss(float x, float mu, float sigma) {
    float d = (x - mu) / sigma;
    return exp(-d * d);
}

/// Composites one painted coast at tide `level` (height units).
/// `atlas` holds three equal panels side by side: land | water | data (R height,
/// G foam lace, B foam wander). SwiftUI shaders accept a single image argument.
/// `motion` 0…1 scales the gentle swash and foam drift (0 under Reduce Motion).
static half4 panel(texture2d<half> atlas, sampler s, float2 uv, int index, float texelX) {
    float x = clamp(uv.x, texelX, 1.0 - texelX);
    return atlas.sample(s, float2((x + float(index)) / 3.0, clamp(uv.y, 0.0, 1.0)));
}

[[ stitchable ]] half4 tideScene(float2 position, half4 color,
                                 float2 size, float texAspect, float level, float time, float motion,
                                 texture2d<half> atlas,
                                 float3 turquoise, float3 seabedTint, float3 foamColor, float wetDarkening) {
    constexpr sampler linear(address::clamp_to_edge, filter::linear);
    float2 uv = position / size;
    float viewAspect = size.x / size.y;
    if (viewAspect > texAspect) {
        uv.y = (uv.y - 0.5) * (texAspect / viewAspect) + 0.5;
    } else {
        uv.x = (uv.x - 0.5) * (viewAspect / texAspect) + 0.5;
    }
    float texelX = 1.5 * 3.0 / float(atlas.get_width());

    half4 data = panel(atlas, linear, uv, 2, texelX);
    float h = kHeightMin + kHeightSpan * float(data.r);
    // Gentle swash: the edge laps a little, never far enough to mislead.
    float swash = motion * 0.004 * sin(time * 0.9 + uv.y * 14.0 + uv.x * 5.0);
    float depth = level + swash - h;

    float3 l = float3(panel(atlas, linear, uv, 0, texelX).rgb);
    float3 w = float3(panel(atlas, linear, uv, 1, texelX).rgb);
    float2 drift = motion * float2(0.0015 * sin(time * 0.21), 0.0012 * sin(time * 0.13));
    float lace = float(panel(atlas, linear, uv + drift, 2, texelX).g);
    float wander = float(data.b) * 2.0 - 1.0;

    float3 col;
    if (depth <= 0.0) {
        float wet = 1.0 - sstep(0.0, 0.016, -depth);
        col = l * (1.0 - wetDarkening * wet);
        col = mix(col, mix(turquoise, l, 0.5), 0.14 * wet);
    } else {
        float deep = sstep(0.02, 0.32, depth);
        float3 seabed = l * seabedTint;
        float3 shallow = mix(seabed, turquoise, 0.38);
        col = mix(shallow, w, deep);
    }

    float d = depth + wander * 0.04;
    // The edge band stops at the waterline: no foam on dry sand.
    float edge = gauss(depth, 0.006, 0.02) * sstep(-0.008, 0.002, depth);
    float band1 = gauss(d, 0.05, 0.022) * 0.95;
    float band2 = gauss(d, 0.105, 0.02) * 0.8;
    float band3 = gauss(d, 0.16, 0.012) * 0.5;
    // Surf only breaks in shallow water.
    float shallowGate = 1.0 - sstep(0.17, 0.21, depth);
    float band = max(max(edge, band1), max(band2, band3)) * shallowGate;
    float threshold = 0.42 + (0.5 - lace) * 0.5;
    float foam = sstep(threshold - 0.07, threshold + 0.07, band);
    float wash = band * lace * 0.3 * sstep(-0.004, 0.004, depth);
    col = mix(col, foamColor, clamp(foam * 0.97 + wash, 0.0, 1.0));
    return half4(half3(col), 1.0h);
}
