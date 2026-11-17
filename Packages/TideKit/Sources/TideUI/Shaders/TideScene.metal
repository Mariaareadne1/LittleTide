#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Painted coast + liquid glass, in one pass.
//
// The coast mirrors ArtForge/Composite.swift (keep the constants in sync). The glass is a
// port of the optical model in github.com/Mariaareadne1/glass-studies (src/glass/shaders.ts):
// a rounded-rect slab with a convex squircle bevel, refraction through IOR 1.52 with
// per-channel aberration, golden-angle frost, Fresnel rim reflection, body absorption,
// a milky rim with a separation ring, an upper-edge light streak, corner glint, lower-wall
// glint, a restrained spectral fringe, a crisp hairline and a soft contact shadow.
// Because the glass re-samples the painted scene itself, it refracts the real artwork.

constant float kHeightMin = 0.05;
constant float kHeightSpan = 0.75;
constant float PI = 3.14159265;

static float sstep(float a, float b, float x) {
    float t = clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

static float gauss(float x, float mu, float sigma) {
    float d = (x - mu) / sigma;
    return exp(-d * d);
}

static float3 screenBlend(float3 a, float3 b) { return 1.0 - (1.0 - a) * (1.0 - b); }

// ------------------------------------------------------------------ painted scene

struct Scene {
    texture2d<half> atlas;
    float2 size;
    float texAspect;
    float level;
    float time;
    float motion;
    float3 turquoise;
    float3 seabedTint;
    float3 foamColor;
    float wetDarkening;
    float underwater;
    float4 scrim;      // top scrim end (pt), bottom scrim start (pt), top alpha, bottom alpha
};

constant float3 kOceanDeep = float3(0.047, 0.243, 0.298);

static half4 panel(texture2d<half> atlas, float2 uv, int index) {
    constexpr sampler linear(address::clamp_to_edge, filter::linear);
    float texelX = 1.5 * 3.0 / float(atlas.get_width());
    float x = clamp(uv.x, texelX, 1.0 - texelX);
    return atlas.sample(linear, float2((x + float(index)) / 3.0, clamp(uv.y, 0.0, 1.0)));
}

/// Aspect-fill mapping from view points to scene uv.
static float2 uvFor(float2 p, Scene s) {
    float2 uv = p / s.size;
    float viewAspect = s.size.x / s.size.y;
    if (viewAspect > s.texAspect) {
        uv.y = (uv.y - 0.5) * (s.texAspect / viewAspect) + 0.5;
    } else {
        uv.x = (uv.x - 0.5) * (viewAspect / s.texAspect) + 0.5;
    }
    return uv;
}

static float3 coast(float2 uv, Scene s) {
    half4 data = panel(s.atlas, uv, 2);
    float h = kHeightMin + kHeightSpan * float(data.r);
    float swash = s.motion * 0.004 * sin(s.time * 0.9 + uv.y * 14.0 + uv.x * 5.0);
    float depth = s.level + swash - h;

    float3 l = float3(panel(s.atlas, uv, 0).rgb);
    float3 w = float3(panel(s.atlas, uv, 1).rgb);
    float2 drift = s.motion * float2(0.0015 * sin(s.time * 0.21), 0.0012 * sin(s.time * 0.13));
    float lace = float(panel(s.atlas, uv + drift, 2).g);
    float wander = float(data.b) * 2.0 - 1.0;

    float3 col;
    if (depth <= 0.0) {
        float wet = 1.0 - sstep(0.0, 0.016, -depth);
        col = l * (1.0 - s.wetDarkening * wet);
        col = mix(col, mix(s.turquoise, l, 0.5), 0.14 * wet);
    } else {
        float deep = sstep(0.02, 0.32, depth);
        float3 seabed = l * s.seabedTint;
        float3 shallow = mix(seabed, s.turquoise, 0.38);
        col = mix(shallow, w, deep);
    }

    float d = depth + wander * 0.04;
    float edge = gauss(depth, 0.006, 0.02) * sstep(-0.008, 0.002, depth);
    float band1 = gauss(d, 0.05, 0.022) * 0.95;
    float band2 = gauss(d, 0.105, 0.02) * 0.8;
    float band3 = gauss(d, 0.16, 0.012) * 0.5;
    float shallowGate = 1.0 - sstep(0.17, 0.21, depth);
    float band = max(max(edge, band1), max(band2, band3)) * shallowGate;
    float threshold = 0.42 + (0.5 - lace) * 0.5;
    float foam = sstep(threshold - 0.07, threshold + 0.07, band);
    float wash = band * lace * 0.3 * sstep(-0.004, 0.004, depth);
    return mix(col, s.foamColor, clamp(foam * 0.97 + wash, 0.0, 1.0));
}

/// Deep water seen from just below the surface: the backdrop of the detail section.
static float3 underwater(float2 uv, Scene s) {
    float3 w = float3(panel(s.atlas, uv, 1).rgb);
    float2 drift = s.motion * float2(0.002 * sin(s.time * 0.17), 0.0015 * s.time * 0.05);
    float lace = float(panel(s.atlas, fract(uv * 1.6 + drift), 2).g);
    // Dark enough that white type set directly on it passes WCAG AA; the painted strokes
    // and boats still read as texture through the deep teal.
    float3 col = mix(kOceanDeep, w, 0.34) * 0.86;
    col += float3(0.55, 0.85, 0.82) * pow(lace, 3.0) * 0.045; // faint caustic light
    return col;
}

/// The scene (with its legibility scrims) at view point p.
static float3 sceneAt(float2 p, Scene s) {
    float2 uv = uvFor(p, s);
    float3 col = s.underwater > 0.5 ? underwater(uv, s) : coast(uv, s);
    if (s.underwater < 0.5) {
        float top = (1.0 - sstep(0.0, s.scrim.x, p.y)) * s.scrim.z;
        // reaches ~0.62 a third of the way down the scrim and full strength by two thirds
        float bottom = sstep(s.scrim.y, s.scrim.y + (s.size.y - s.scrim.y) * 0.62, p.y) * s.scrim.w;
        col = mix(col, kOceanDeep, clamp(max(top, bottom), 0.0, 1.0));
    }
    return col;
}

// ------------------------------------------------------------------ glass

static float sdRR(float2 p, float2 h, float r) {
    float2 q = abs(p) - (h - r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

static float2 outwardRR(float2 p, float2 h, float r) {
    float2 q = abs(p) - (h - r);
    float2 n;
    if (q.x > 0.0 && q.y > 0.0) n = normalize(q);
    else n = q.x > q.y ? float2(1.0, 0.0) : float2(0.0, 1.0);
    return n * sign(p + 1e-6);
}

struct Material {
    float bevel, thickness, refraction, frost, aberration, specular, milk;
    float3 tint;
    float absorb;
};

/// 0 = text card (frosted, smoked teal so white type reads), 1 = button (thicker, clearer).
static Material materialFor(float kind, float radius) {
    Material m;
    if (kind < 0.5) {
        m.bevel = 26.0; m.thickness = 18.0; m.refraction = 1.0; m.frost = 0.62; m.aberration = 0.4;
        m.specular = 1.0; m.milk = 0.6; m.tint = float3(0.09, 0.33, 0.39); m.absorb = 0.48;
    } else {
        m.bevel = min(radius, 22.0); m.thickness = 26.0; m.refraction = 1.0; m.frost = 0.3; m.aberration = 0.55;
        m.specular = 1.25; m.milk = 0.7; m.tint = float3(0.07, 0.27, 0.32); m.absorb = 0.46;
    }
    return m;
}

static float3 frosted(float2 p, float radius, Scene s) {
    if (radius < 0.15) return sceneAt(p, s);
    float3 acc = sceneAt(p, s) * 0.2;
    float w = 0.2;
    for (int k = 0; k < 7; k++) {
        float fk = float(k);
        float a = fk * 2.39996;
        float rr = radius * sqrt((fk + 0.5) / 7.0);
        acc += sceneAt(p + float2(cos(a), sin(a)) * rr, s);
        w += 1.0;
    }
    return acc / w;
}

/// Shades the glass panel with centre c, half-size h and corner radius r (all points,
/// y down) over `base`. Returns base unchanged far from the panel.
static float3 shadeGlass(float2 p, float3 base, float2 c, float2 h, float r, float kind, Scene s) {
    float2 lp = p - c;
    float sd = sdRR(lp, h, r);
    if (sd > 2.0) return base;
    float inside = 1.0 - sstep(-0.6, 0.6, sd);
    if (inside <= 0.0) return base;

    Material M = materialFor(kind, r);
    float2 outward = outwardRR(lp, h, r);           // y down
    float bevel = max(M.bevel, 1.0);
    float depth = max(-sd, 0.0);
    float t = clamp(depth / bevel, 0.0, 1.0);
    float om = 1.0 - t;
    float om4 = om * om * om * om;
    float hgt = pow(max(1.0 - om4, 0.0), 0.25);     // convex squircle profile
    float slope = min(om * om * om * pow(max(1.0 - om4, 1e-4), -0.75), 6.0);
    float sl = slope * M.thickness / bevel;

    float3 n3 = normalize(float3(outward * sl, 1.0));
    float3 rr = refract(float3(0.0, 0.0, -1.0), n3, 1.0 / 1.52);
    float travel = M.thickness * (0.35 + 0.65 * hgt);
    float2 disp = rr.xy / max(-rr.z, 0.25) * travel * M.refraction;

    // clearer centre, optical activity toward the perimeter
    float ab = M.aberration;
    float frostR = M.frost * (0.3 + 0.7 * om) * 7.0;
    // one frosted sample, with red and blue pulled apart along the displacement
    float3 frost = frosted(p + disp, frostR, s);
    float rSplit = sceneAt(p + disp * (1.0 - 0.35 * ab), s).r;
    float bSplit = sceneAt(p + disp * (1.0 + 0.55 * ab), s).b;
    float split = clamp(ab * (0.25 + 0.75 * om), 0.0, 1.0) * 0.6;
    float3 refr = float3(mix(frost.r, rSplit, split), frost.g, mix(frost.b, bSplit, split));

    // reflected surroundings in the thick rim
    float3 refl = sceneAt(p + outward * (bevel * (0.4 + 1.6 * om)), s);
    float fres = pow(1.0 - n3.z, 1.6);
    refr = mix(refr, screenBlend(refr, refl * 0.55), clamp(fres * 1.2, 0.0, 0.75));

    // body: absorbs toward its colour, deepest in the middle, bright thin-walled rim
    float absorb = M.absorb * (0.42 + 0.58 * hgt);
    refr = mix(refr, refr * (M.tint * 1.1), absorb * 0.8);
    refr = mix(refr, M.tint, absorb * 0.62);

    // lighting: key light from the upper left
    float3 L = normalize(float3(-0.5, -0.62, 0.62));
    float2 Ld = normalize(L.xy);
    float facing = dot(outward, Ld);
    float3 refv = reflect(float3(0.0, 0.0, -1.0), n3);
    float spec = pow(max(dot(refv, L), 0.0), 60.0) * M.specular;
    float rimLit = fres * (0.5 * max(facing, 0.0) + 0.2 * max(-facing, 0.0));
    float rimShade = fres * (0.08 + 0.12 * max(-facing, 0.0));

    // milky rim: the thick wall scatters light; brighter toward the key light
    float band = 1.0 - sstep(0.0, 0.46, t);
    float lit = 0.28 + 0.72 * pow(facing * 0.5 + 0.5, 1.4);
    refr = screenBlend(refr, float3(1.0, 0.995, 1.0) * M.milk * band * band * lit * 0.6);
    float ring = exp(-pow((t - 0.64) / 0.12, 2.0));
    refr *= 1.0 - ring * 0.04 * M.milk;

    // narrow light streak along the upper edge, glint in the lit corner, lower-wall glint
    float topness = sstep(0.05, 0.85, -outward.y * 0.85 + facing * 0.35);
    float streak = exp(-pow((t - 0.17) / 0.06, 2.0)) * topness;
    float2 cornerDir = normalize(float2(-0.72, -0.69));
    float glint = exp(-pow((t - 0.12) / 0.05, 2.0)) * pow(max(dot(outward, cornerDir), 0.0), 28.0) * 0.55;
    float lowGlint = exp(-pow((t - 0.22) / 0.12, 2.0)) * sstep(0.2, 0.9, outward.y) * 0.3;
    float sheen = 0.05 * sstep(-0.1, 1.0, -lp.y / h.y) * hgt * M.specular;
    float3 caustic = 0.08 * fres * max(-facing, 0.0) * 0.5;

    // restrained spectral fringe on the rim wall (cyan / lilac / peach)
    float ang = atan2(lp.y, lp.x) / (2.0 * PI) + 0.5;
    float3 film = 0.5 + 0.5 * cos(2.0 * PI * (ang * 2.0 + facing * 0.3 + float3(0.55, 0.78, 0.0)));
    float fringe = exp(-pow((t - 0.08) / 0.07, 2.0)) * (0.5 + 0.5 * abs(outward.x)) * M.aberration;
    float3 rimCol = mix(float3(1.0), film, 0.35);

    refr = refr * (1.0 - rimShade) + float3(spec * 0.9 + sheen) + float3(streak * 0.62 + lowGlint + glint) * M.specular
         + rimCol * rimLit * 0.5 + caustic + (film - 0.45) * fringe * 0.28;
    // crisp manufactured hairline
    float line = exp(-pow(sd / 0.45, 2.0));
    refr += float3(line * (0.22 + 0.36 * max(facing, 0.0)));

    return mix(base, refr, inside);
}

/// Soft contact shadow cast by a panel onto the scene beneath it.
static float shadowOf(float2 p, float2 c, float2 h, float r, float strength) {
    float soft = 10.0;
    float2 lp = p - (c + float2(0.0, soft * 0.45));
    float sd = sdRR(lp, h * float2(0.97, 0.95), r);
    float broad = 1.0 - sstep(-soft * 1.2, soft * 2.0, sd);
    float2 lp2 = p - (c + float2(0.0, 1.5));
    float sd2 = sdRR(lp2, h, r);
    float tight = exp(-max(sd2, 0.0) / 2.2) * step(0.0, sd2 + 2.0);
    return clamp((broad * 0.55 + tight * 0.35) * strength, 0.0, 1.0);
}

/// `panels` = [count, then per panel: cx, cy, hw, hh, radius, kind, 0, 0] in view points.
[[ stitchable ]] half4 tideScene(float2 position, half4 color,
                                 float2 size, float texAspect, float level, float time, float motion,
                                 texture2d<half> atlas,
                                 float3 turquoise, float3 seabedTint, float3 foamColor, float wetDarkening,
                                 float underwaterMode, float4 scrim,
                                 device const float *panels, int panelFloats) {
    Scene s = { atlas, size, texAspect, level, time, motion, turquoise, seabedTint, foamColor, wetDarkening, underwaterMode, scrim };
    float3 col = sceneAt(position, s);

    int count = panelFloats > 0 ? min(int(panels[0]), (panelFloats - 1) / 8) : 0;
    // contact shadows first, then glass (each panel refracts the scene, not other panels)
    float sh = 0.0;
    for (int i = 0; i < count; i++) {
        int o = 1 + i * 8;
        float2 c = float2(panels[o], panels[o + 1]);
        float2 h = float2(panels[o + 2], panels[o + 3]);
        sh = max(sh, shadowOf(position, c, h, panels[o + 4], panels[o + 5] < 0.5 ? 0.42 : 0.5));
    }
    col *= 1.0 - sh * float3(0.32, 0.3, 0.26);
    for (int i = 0; i < count; i++) {
        int o = 1 + i * 8;
        float2 c = float2(panels[o], panels[o + 1]);
        float2 h = float2(panels[o + 2], panels[o + 3]);
        col = shadeGlass(position, col, c, h, min(panels[o + 4], min(h.x, h.y)), panels[o + 5], s);
    }
    return half4(half3(col), 1.0h);
}
