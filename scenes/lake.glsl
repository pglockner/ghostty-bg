// A calm lake at golden hour, seen from straight above: the water runs
// from soft blue to cream and pale gold where it mirrors the low sun, and
// tiny boats cross it, each trailing a widening wake. Made for light
// themes. ghostty-bg puts `const float STRENGTH` (the opacity) in front of
// this file.

const int BOATS = 6;
const float SPEED = 0.012;   // screen heights per second, roughly
const float WAKE = 0.45;     // how far behind a boat its wake reaches
const float KELVIN = 0.354;  // tan(19.5 degrees): a wake's arms spread at this
// The water, top left to bottom right: the open sky's blue, cream, then
// the low sun's gold.
const vec3 BLUE = vec3(0.32, 0.47, 0.60);
const vec3 CREAM = vec3(0.90, 0.86, 0.76);
const vec3 GOLD = vec3(0.97, 0.82, 0.52);
const vec3 FOAM = vec3(1.00, 0.98, 0.94);
// Shadows fall away from the sun, toward the top left.
const vec2 SHADOW = vec2(-0.6, 0.45);

// For the boats' own fixed traits: small inputs, so sin() is precise.
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// For anything whose input grows with time: Dave Hoskins' hash without
// sine (https://www.shadertoy.com/view/4djSRW, Copyright (c) 2014 David
// Hoskins, MIT License). A sine hash fed a growing number stops being
// random once 32-bit floats can't hold sin() of it precisely.
float hash3(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise, 0 to 1.
float noise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
                   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
                   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The open water at q, g of the way from the top left corner to the
// bottom right one: the sky's colors with slow, faint ripples over them,
// and the sun glinting off them toward its end.
vec3 water(vec2 q, float g) {
    vec3 c = g < 0.5 ? mix(BLUE, CREAM, smoothstep(0.0, 0.5, g)) : mix(CREAM, GOLD, smoothstep(0.5, 1.0, g));
    float t = iTime * 0.12;
    float ripple = noise(vec3(q * vec2(9.0, 26.0), t)) * 0.6 + noise(vec3(q * vec2(23.0, 61.0), t * 1.7)) * 0.4;
    c *= 0.96 + 0.08 * ripple;
    // At most one glint per small cell, each lasting half a second.
    vec2 g2 = q * 140.0;
    vec2 cell = floor(g2);
    float when = floor(iTime * 2.0);
    if (hash3(vec3(cell, when)) > 0.985) {
        float d = length(fract(g2) - 0.5);
        c = mix(c, FOAM, (1.0 - smoothstep(0.0, 0.3, d)) * g * g);
    }
    return c;
}

// How much of the hull, half L long and half W wide, covers the point x
// along it (bow ahead) and y across it: a pointed bow and a broad stern.
float hull(float x, float y, float L, float W, float px) {
    float u = x / L;
    if (abs(u) >= 1.0) return 0.0;
    float hw = u > 0.0 ? W * (1.0 - u * u) : W * sqrt(1.0 - u * u * u * u);
    return 1.0 - smoothstep(-px, px, abs(y) - hw);
}

// Boat i, with its wake, over the water. Each holds its own heading and
// speed, and wraps round off-screen once its wake is clear of the edge.
vec3 boat(vec3 lake, vec2 q, float aspect, float px, int i) {
    float n = float(i);
    float a = hash(n + 1.0) * 6.2832;
    vec2 h = vec2(cos(a), sin(a)), side = vec2(-h.y, h.x);
    float L = mix(0.014, 0.024, hash(n + 2.0));
    float W = L * 0.38;
    // Room off each edge: where it leaves, for the wake trailing behind;
    // where it comes in, for the arms where they spread sideways past it.
    vec2 ah = abs(h), across = KELVIN * ah.yx;
    vec2 come = L + 0.02 + WAKE * max(across - ah, 0.0);
    vec2 leave = L + 0.02 + WAKE * (ah + across);
    vec2 span = vec2(aspect, 1.0) + come + leave;
    float travel = SPEED * mix(0.7, 1.3, hash(n + 3.0)) * iTime;
    vec2 c = mod(vec2(hash(n + 4.0), hash(n + 5.0)) * span + h * travel, span) - mix(leave, come, step(0.0, h));

    vec2 rel = q - c;
    float x = dot(rel, h), y = dot(rel, side);
    if (x > 2.0 * L || x < -WAKE || abs(y) > KELVIN * (L - x) + 4.0 * W) return lake;

    // The wake, from the bow back: two arms spreading at the Kelvin angle,
    // widening and fading, feathered into short crests, each with a faint
    // trough beside it; low swells across the V between them; and churned
    // foam right behind the stern.
    float b = L - x;
    if (b > 0.0) {
        float fade = pow(1.0 - b / WAKE, 2.0) * smoothstep(0.0, 0.02, b);
        float e = abs(y) - KELVIN * b;
        float w = px + 0.025 * b;
        float crests = 0.7 + 0.3 * cos((b + abs(y) * 1.6) * 150.0);
        float arm = exp(-e * e / (w * w)) * crests;
        float trough = exp(-pow((e - 1.8 * w) / w, 2.0));
        float swell = (1.0 - smoothstep(-w, 0.0, e)) * (0.5 + 0.5 * cos(b * 95.0)) * 0.25;
        float s = -x - 0.9 * L;
        float churn = s > 0.0 ? (1.0 - smoothstep(0.0, W * (0.6 + 12.0 * s), abs(y))) * exp(-s * 14.0)
                              * (0.5 + 0.5 * noise(vec3(rel / L * 3.0, iTime * 1.5))) : 0.0;
        lake = mix(lake, FOAM, clamp(arm * 0.6 + swell + churn * 0.8, 0.0, 1.0) * fade);
        lake *= 1.0 - 0.16 * trough * fade;
    }

    // Its shadow, then the boat: a rowboat in weathered wood, or a white
    // skiff with a small cabin, each with a pale rim.
    vec2 sr = rel - SHADOW * L * 0.5;
    lake *= 1.0 - 0.25 * hull(dot(sr, h), dot(sr, side), L, W, 0.3 * W + px);
    float on = hull(x, y, L, W, px);
    if (on <= 0.0) return lake;
    float inner = hull(x * 1.08, y, L, W * 0.72, px);
    vec3 col;
    if (hash(n + 6.0) < 0.5) {
        float thwarts = 1.0 - smoothstep(0.0, 1.5 * px, abs(abs(x / L + 0.1) - 0.3) * L - 0.08 * L);
        col = mix(vec3(0.62, 0.50, 0.40), vec3(0.50, 0.40, 0.32), thwarts);
    } else {
        float cabin = step(abs(x / L - 0.05), 0.22) * step(abs(y), 0.5 * W);
        col = mix(vec3(0.95, 0.93, 0.89), vec3(0.62, 0.66, 0.70), cabin);
    }
    col = mix(vec3(0.93, 0.90, 0.84), col, inner);
    return mix(lake, col, on);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    // Ghostty's y runs downward; q runs up from the bottom, in screen heights.
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.y;
    float px = 1.0 / iResolution.y;
    float g = clamp(dot(q - vec2(0.0, 1.0), vec2(aspect, -1.0)) / (aspect * aspect + 1.0), 0.0, 1.0);

    vec3 lake = water(q, g);
    for (int i = 0; i < BOATS; i++) lake = boat(lake, q, aspect, px, i);

    // 1 on the background, fading to 0 as the pixel moves away from it.
    float mask = 1.0 - smoothstep(0.02, 0.2, distance(term.rgb, iBackgroundColor));

    fragColor = vec4(term.rgb + (lake - iBackgroundColor) * STRENGTH * mask, term.a);
}
