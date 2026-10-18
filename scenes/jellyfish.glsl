// Sea nettles swimming slowly upward through deep blue water: lit, striped
// 3D bells trailing frilled oral arms and fine tentacles, with light
// rippling over them and specks drifting down. ghostty-bg puts
// `const float STRENGTH` (the opacity) in front of this file.

const int JELLIES = 10;
const float SPEED = 0.010;                    // screen heights per second, roughly
const vec3 LIGHT = vec3(0.259, 0.864, 0.432);  // from above, a little right and front
const float CUT = -0.1;                       // where the bell's sphere is cut open

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

// Smooth value noise, 0 to 1.
float noise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
                   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
                   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

mat3 rotX(float b) { float c = cos(b), s = sin(b); return mat3(1, 0, 0, 0, c, s, 0, -s, c); }
mat3 rotZ(float a) { float c = cos(a), s = sin(a); return mat3(c, s, 0, -s, c, 0, 0, 0, 1); }

// Lighter toward the surface, with faint shafts of light swaying in.
vec3 water(vec2 q) {
    vec3 c = mix(vec3(0.00, 0.03, 0.12), vec3(0.03, 0.20, 0.42), smoothstep(0.0, 1.0, q.y));
    float shaft = sin(q.x * 9.0 + q.y * 3.0 + sin(iTime * 0.07) * 2.0)
                * sin(q.x * 4.3 - q.y * 1.7 + iTime * 0.05);
    return c + vec3(0.05, 0.10, 0.14) * max(shaft, 0.0) * q.y * q.y;
}

// Specks sinking slowly, one at most per cell of a coarse grid.
float snow(vec2 q) {
    vec2 g = q * 30.0 + vec2(0.0, iTime * 0.15);
    float h = hash(dot(floor(g), vec2(1.0, 57.0)));
    if (h > 0.25) return 0.0;
    vec2 p = vec2(hash(h * 13.0), hash(h * 29.0)) * 0.8 + 0.1;
    return (1.0 - smoothstep(0.0, 0.08, length(fract(g) - p))) * 0.5;
}

// Light rippling down from the surface, in a shifting net.
float caustics(vec2 q) {
    float t = iTime * 0.4;
    vec2 p = q * 22.0;
    float c = sin(p.x + sin(p.y * 0.8 + t) * 1.6 + t) * sin(p.y + sin(p.x * 0.7 - t) * 1.6 - t * 0.8);
    return pow(abs(c), 3.0);
}

// The bell's surface at u, a point on the unit sphere it is cut from (y
// toward the top), seen with world normal nw: peach, mottled, with dark
// bands and red canals running down from a ring at the top, a pale rim
// dotted with sense organs, lit from above, and brighter and more opaque
// where it curves away from the viewer.
vec4 skin(vec3 u, vec3 nw, vec2 q, float seed) {
    float phi = atan(u.z, u.x);
    float bands = smoothstep(0.1, 0.8, cos(phi * 8.0)) * (1.0 - smoothstep(0.45, 0.92, u.y));
    float canals = smoothstep(0.93, 1.0, -cos(phi * 8.0));
    float ring = 1.0 - smoothstep(0.0, 0.04, abs(u.y - 0.88));
    float rim = 1.0 - smoothstep(CUT, CUT + 0.2, u.y);
    // Sixteen round dots just above the rim: how far round to the nearest
    // (as arc length on the unit sphere) and how far above or below it.
    float arc = (fract(phi / 6.2832 * 16.0) - 0.5) * 0.393;
    float dots = 1.0 - smoothstep(0.02, 0.035, length(vec2(arc, u.y - CUT - 0.08)));

    vec3 base = mix(vec3(1.0, 0.74, 0.55), vec3(1.0, 0.56, 0.32), 1.0 - u.y);
    base *= 0.8 + 0.35 * noise(u * 7.0 + seed * 10.0);
    base = mix(base, vec3(0.55, 0.22, 0.12), 0.55 * bands);
    base = mix(base, vec3(0.9, 0.25, 0.12), 0.7 * max(canals, ring));
    base = mix(base, vec3(1.0, 0.88, 0.75), 0.5 * rim);
    base = mix(base, vec3(0.35, 0.12, 0.08), dots);

    float diffuse = 0.35 + 0.65 * max(dot(nw, LIGHT), 0.0);
    float fresnel = pow(1.0 - abs(nw.z), 3.0);
    vec3 col = base * diffuse + caustics(q) * 0.35 * max(nw.y, 0.0) + vec3(0.6, 0.8, 1.0) * fresnel * 0.5;
    return vec4(col, mix(0.55, 0.92, fresnel));
}

// How much of a strand covers q: it hangs from p0 along v for len, width
// wide at the root and narrowing, swaying in waves that run down it and
// curving toward the bottom of the screen. frill ruffles its width. t is
// set to how far along it q is, 0 at the root and 1 at the tip.
float strand(vec2 q, vec2 p0, vec2 v, float len, float width, float sway, float frill,
             float phase, out float t) {
    vec2 rel = q - p0;
    vec2 side = vec2(-v.y, v.x);
    float along = dot(rel, v) / len;
    // Kept in 0 to 1 even off the strand, where callers still fade by it.
    t = clamp(along, 0.0, 1.0);
    if (along <= 0.0 || along >= 1.0) return 0.0;
    float off = sway * t * sin(t * 6.0 - iTime * 1.2 + phase) - 0.3 * len * t * t * side.y;
    float w = width * (1.0 - 0.5 * t) * (1.0 + frill * sin(t * 30.0 - iTime * 1.5 + phase));
    // Faded in at the root, so it grows out of the bell without a hard edge.
    return (1.0 - smoothstep(0.0, w, abs(dot(rel, side) - off))) * smoothstep(0.0, 0.12, t);
}

// Jellyfish i, painted over sea. Later ones are bigger and clearer, as if
// nearer, and are drawn in front. Each heads its own way, mostly upward,
// tipped to the side and toward or away from the viewer, and rocks a
// little. The bell pulses, narrowing and lengthening as it contracts, and
// each contraction pushes it on a little faster.
vec3 jelly(vec3 sea, vec2 q, float aspect, int i) {
    float n = float(i);
    float r = mix(0.045, 0.11, (n + hash(n + 1.0)) / float(JELLIES));
    float fade = mix(0.5, 1.0, n / float(JELLIES - 1));
    float tl = r * mix(3.0, 4.5, hash(n + 6.0));

    float roll = (hash(n + 7.0) - 0.5) * 1.1;
    float pitch = (hash(n + 8.0) - 0.5) * 1.6;
    vec2 heading = (rotZ(roll) * rotX(pitch) * vec3(0.0, 1.0, 0.0)).xy;

    // Its speed is speed * (1 + 0.9 sin ph): fastest while contracting.
    float ph = iTime * 0.9 + n * 1.7;
    float squeeze = 0.5 + 0.5 * sin(ph);  // 1 when fully contracted
    float travel = SPEED * mix(0.6, 1.4, hash(n + 3.0)) * (iTime - cos(ph));
    // It wraps round off-screen, once its tentacles are clear of the edge.
    // They trail mostly downward, so less room is needed at the sides.
    vec2 m = vec2(1.5 * r + 0.6 * tl, 1.3 * r + tl);
    vec2 span = vec2(aspect, 1.0) + 2.0 * m;
    vec2 c = mod(vec2(hash(n + 4.0), hash(n + 2.0)) * span + heading * travel, span) - m;
    if (length(q - c) > 1.5 * r + tl) return sea;

    mat3 rot = rotZ(roll + 0.12 * sin(iTime * 0.13 + n * 2.1)) * rotX(pitch + 0.1 * sin(iTime * 0.11 + n));
    float R = r * (1.0 - 0.08 * squeeze);
    float H = r * (0.85 + 0.12 * squeeze);

    // Tentacles from the rim and arms from the middle, trailing away from
    // the heading: shorter the more the bell faces the viewer.
    vec2 back = -(rot * vec3(0.0, 1.0, 0.0)).xy;
    float fore = length(back);
    vec2 v = fore > 0.05 ? back / fore : vec2(0.0, -1.0);
    float len = tl * max(fore, 0.3);
    float t;
    for (int k = 0; k < 8; k++) {
        float fk = float(k), a = fk / 8.0 * 6.2832 + n;
        vec2 p0 = c + (rot * vec3(0.95 * R * cos(a), CUT * H, 0.95 * R * sin(a))).xy;
        float s = strand(q, p0, v, len * mix(0.8, 1.0, hash(n * 7.0 + fk)), 0.03 * r, 0.25 * r, 0.0, fk * 0.9 + n, t);
        sea = mix(sea, vec3(0.95, 0.55, 0.45), s * pow(1.0 - t, 1.2) * 0.45 * fade);
    }
    for (int k = 0; k < 4; k++) {
        float fk = float(k), a = fk / 4.0 * 6.2832 + n * 0.7;
        vec2 p0 = c + (rot * vec3(0.25 * R * cos(a), CUT * H, 0.25 * R * sin(a))).xy;
        float s = strand(q, p0, v, len * 0.85, 0.12 * r, 0.35 * r, 0.4, fk * 1.9 + n, t);
        float wisp = 0.4 + 0.6 * noise(vec3((q - c) / r * 6.0, fk + iTime * 0.2));
        sea = mix(sea, vec3(1.0, 0.87, 0.82), s * wisp * pow(1.0 - t, 0.8) * 0.55 * fade);
    }

    // The bell: an ellipsoid cut open underneath. Find where the line of
    // sight through q crosses it, in the bell's own frame scaled to a unit
    // sphere, and paint the far wall (seen from inside) then the near one.
    mat3 inv = transpose(rot);
    vec3 rad = vec3(R, H, R);
    vec3 o = inv * vec3(q - c, 0.0) / rad;
    vec3 d = inv * vec3(0.0, 0.0, -1.0) / rad;
    float A = dot(d, d), B = dot(o, d), disc = B * B - A * (dot(o, o) - 1.0);
    if (disc <= 0.0) return sea;
    float s = sqrt(disc);
    float edge = smoothstep(0.0, 0.25 * r, 2.0 * s / A);  // soften the outline
    for (int side = 0; side < 2; side++) {
        vec3 u = o + (-B + (side == 0 ? s : -s)) / A * d;
        float on = smoothstep(CUT, CUT + 0.04, u.y) * edge * fade;
        if (on <= 0.0) continue;
        vec3 nw = normalize(rot * (u / rad));
        vec4 sk = skin(u, side == 0 ? -nw : nw, q, n);
        if (side == 0) sk.rgb *= 0.6;
        sea = mix(sea, sk.rgb, sk.a * on);
    }
    return sea;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    // Ghostty's y runs downward; q runs up from the bottom, in screen heights.
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.y;

    vec3 sea = water(q) + snow(q) * vec3(0.5, 0.6, 0.7);
    for (int i = 0; i < JELLIES; i++) sea = jelly(sea, q, aspect, i);

    // 1 on the background, fading to 0 as the pixel moves away from it.
    float mask = 1.0 - smoothstep(0.02, 0.2, distance(term.rgb, iBackgroundColor));

    fragColor = vec4(term.rgb + (sea - iBackgroundColor) * STRENGTH * mask, term.a);
}
