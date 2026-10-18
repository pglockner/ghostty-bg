// A calm lake at golden hour, seen from straight above: the water runs
// from soft blue to cream and pale gold where it mirrors the low sun, and
// tiny boats cross it, each trailing a widening, uneven wake that
// reinforces any other it crosses. Made for light themes. ghostty-bg puts
// `const float STRENGTH` (the opacity) in front of this file.

const int BOATS = 6;
const float SPEED = 0.012;   // screen heights per second, roughly
const float WAKE = 0.45;     // how far behind a boat its wake reaches
const float KELVIN = 0.354;  // tan(19.5 degrees): a wake's arms spread at this
const float WAVE = 450.0;    // a wake's wavenumber: 2 pi over its wavelength
// The water, top left to bottom right: the open sky's blue, cream, then
// the low sun's gold.
const vec3 BLUE = vec3(0.32, 0.47, 0.60);
const vec3 CREAM = vec3(0.90, 0.86, 0.76);
const vec3 GOLD = vec3(0.97, 0.82, 0.52);
const vec3 FOAM = vec3(1.00, 0.98, 0.94);
// Toward the sun, low over the bottom right; shadows fall the other way.
const vec3 SUN = vec3(0.725, -0.526, 0.444);
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

// Where boat i is, with its heading h and half-length L. Each holds its
// own heading and speed, and wraps round off-screen once its wake is
// clear of the edge.
vec2 boatAt(int i, float aspect, out vec2 h, out float L) {
    float n = float(i);
    float a = hash(n + 1.0) * 6.2832;
    h = vec2(cos(a), sin(a));
    L = mix(0.014, 0.024, hash(n + 2.0));
    // Room off each edge: where it leaves, for the wake trailing behind;
    // where it comes in, for the arms where they spread sideways past it.
    vec2 ah = abs(h), across = KELVIN * ah.yx;
    vec2 come = L + 0.02 + WAKE * max(across - ah, 0.0);
    vec2 leave = L + 0.02 + WAKE * (ah + across);
    vec2 span = vec2(aspect, 1.0) + come + leave;
    float travel = SPEED * mix(0.7, 1.3, hash(n + 3.0)) * iTime;
    return mod(vec2(hash(n + 4.0), hash(n + 5.0)) * span + h * travel, span) - mix(leave, come, step(0.0, h));
}

// The height of boat i's wake at p, in screen heights, signed, so that
// wakes that cross add up where their crests meet and cancel where a crest
// meets a trough. From the bow back: waves across the V, their crests
// bending back toward its arms; short feathered waves along the arms; and
// churned water right behind the stern. Noise wobbles their phase and
// strength, so no two stretches are alike, and it all fades with distance.
float wake(vec2 p, vec2 c, vec2 h, float L, float n) {
    vec2 rel = p - c;
    float x = dot(rel, h), y = abs(dot(rel, vec2(-h.y, h.x)));
    float b = L - x;
    if (b <= 0.0 || b > WAKE) return 0.0;
    float W = 0.38 * L;
    float s = y / (KELVIN * b + W);  // 0 along the track, 1 on the arms
    if (s > 1.6) return 0.0;

    float wobble = 1.8 * noise(vec3(b * 40.0, y * 40.0, iTime * 0.5 + n * 3.0));
    float patchy = 0.5 + noise(vec3(b * 22.0, y * 22.0, iTime * 0.3 + n * 7.0));
    float across = cos(WAVE * 0.6 * b * (1.0 + 0.5 * s * s) + wobble) * (1.0 - smoothstep(0.5, 1.0, s)) * 0.3;
    float arms = cos(WAVE * 1.3 * (0.5 * b + y) + wobble) * exp(-pow((s - 1.0) / 0.15, 2.0));
    float fade = pow(1.0 - b / WAKE, 1.5);
    float height = 0.035 * L * (across + arms) * patchy * fade;

    float st = -x - 0.9 * L;
    if (st > 0.0) {
        float churn = (1.0 - smoothstep(0.0, W * (0.6 + 12.0 * st), y)) * exp(-st * 12.0);
        height += 0.12 * L * churn * (noise(vec3(rel / L * 3.0, iTime * 1.5)) - 0.5);
    }
    return height;
}

// The water's height at p: slow, faint ripples, and every boat's wake.
float surface(vec2 p, vec2 c[BOATS], vec2 h[BOATS], float L[BOATS]) {
    float t = iTime * 0.12;
    float z = 0.0012 * noise(vec3(p * vec2(9.0, 26.0), t)) + 0.0005 * noise(vec3(p * vec2(23.0, 61.0), t * 1.7));
    for (int i = 0; i < BOATS; i++) z += wake(p, c[i], h[i], L[i], float(i));
    return z;
}

// The open water at q, g of the way from the top left corner to the
// bottom right one, its surface tilted by slope: the sky's colors, lit
// brighter on slopes facing the sun and bluer on those facing away, the
// sun glinting gold off the steepest, and foam where the slope is steepest
// of all, as where two wakes reinforce each other.
vec3 water(vec2 q, float g, vec2 slope) {
    vec3 c = g < 0.5 ? mix(BLUE, CREAM, smoothstep(0.0, 0.5, g)) : mix(CREAM, GOLD, smoothstep(0.5, 1.0, g));
    vec3 nrm = normalize(vec3(-slope, 1.0));
    float lit = dot(nrm, SUN) - SUN.z;  // 0 where the water is flat
    c = mix(c * (1.0 + 1.4 * lit), BLUE, clamp(-lit * 1.2, 0.0, 0.35));
    vec3 r = reflect(vec3(0.0, 0.0, -1.0), nrm);
    c += vec3(1.0, 0.85, 0.55) * 0.7 * pow(max(dot(r, SUN), 0.0), 12.0);
    c = mix(c, FOAM, smoothstep(0.5, 0.9, length(slope)) * 0.8);
    // At most one glint per small cell, each lasting half a second.
    vec2 g2 = q * 140.0;
    float when = floor(iTime * 2.0);
    if (hash3(vec3(floor(g2), when)) > 0.985) {
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

// Boat i at c, heading h, over the water: its shadow, then the boat, a
// rowboat in weathered wood or a white skiff with a small cabin, each with
// a pale rim.
vec3 boat(vec3 lake, vec2 q, vec2 c, vec2 h, float L, float px, int i) {
    float W = 0.38 * L;
    vec2 side = vec2(-h.y, h.x);
    vec2 rel = q - c;
    if (length(rel) > 3.0 * L) return lake;
    vec2 sr = rel - SHADOW * L * 0.5;
    lake *= 1.0 - 0.25 * hull(dot(sr, h), dot(sr, side), L, W, 0.3 * W + px);
    float x = dot(rel, h), y = dot(rel, side);
    float on = hull(x, y, L, W, px);
    if (on <= 0.0) return lake;
    float inner = hull(x * 1.08, y, L, W * 0.72, px);
    vec3 col;
    if (hash(float(i) + 6.0) < 0.5) {
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

    vec2 c[BOATS], h[BOATS];
    float L[BOATS];
    for (int i = 0; i < BOATS; i++) c[i] = boatAt(i, aspect, h[i], L[i]);

    // The surface's slope, from its height here and a pixel over each way.
    float z = surface(q, c, h, L);
    vec2 slope = vec2(surface(q + vec2(px, 0.0), c, h, L) - z, surface(q + vec2(0.0, px), c, h, L) - z) / px;

    vec3 lake = water(q, g, slope);
    for (int i = 0; i < BOATS; i++) lake = boat(lake, q, c[i], h[i], L[i], px, i);

    // 1 on the background, fading to 0 as the pixel moves away from it.
    float mask = 1.0 - smoothstep(0.02, 0.2, distance(term.rgb, iBackgroundColor));

    fragColor = vec4(term.rgb + (lake - iBackgroundColor) * STRENGTH * mask, term.a);
}
