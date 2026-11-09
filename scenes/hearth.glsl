// A fire crackling in a brick hearth, played off a worn videotape: two
// logs crossed over a third, and a broken one in front glowing hot where
// it split, all charred and glowing along their cracks under tall lapping
// flames, sparks drifting up and firelight flickering on the sooty
// bricks, seen through soft scanlines, bleeding color, wavering tracking
// and tape grain, with a camcorder's date stamp in the corner and PLAY on
// screen as it starts. For the long nights of winter. ghostty-bg puts
// `const float STRENGTH` (the opacity) and `const bool Y_DOWN` (whether
// fragCoord's y runs down the screen) in front of this file.

// ghostty-bg starts this scene at opacity 0.4.

// How far the fire's middle sits from the right edge, in screen heights,
// keeping it low and to the right however wide the window is.
const float FIRE_RIGHT = 0.62;
const int SPARKS = 14;
const float LINES = 300.0;    // the tape's lines, top to bottom
const float BLEED = 0.007;    // how far color smears right, in screen heights
// The camcorder's clock starts at 11:40 PM on December 24, 1989.
const float CLOCK = 23.0 * 60.0 + 40.0;
const int YEAR = 1989;

// For fixed traits: small inputs, so sin() is precise.
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// For anything whose input grows with time: Dave Hoskins' hashes without
// sine (https://www.shadertoy.com/view/4djSRW, Copyright (c) 2014 David
// Hoskins, MIT License). A sine hash fed a growing number stops being
// random once 32-bit floats can't hold sin() of it precisely.
float hash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float hash3(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise, 0 to 1, and a few octaves of it.
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
               mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += a * noise(p);
        p = p * 2.03 + vec2(17.1, 5.3);
        a *= 0.5;
    }
    return s / 0.9375;
}

// How bright the fire burns just now, around 1: a slow swell with quick
// flickers on top.
float flicker(float t) {
    return 0.8 + 0.25 * noise(vec2(t * 0.7, 3.0)) + 0.12 * noise(vec2(t * 6.0, 7.0));
}

// Black through deep red, orange and yellow to white, as f runs 0 to 1.
vec3 flame(float f) {
    vec3 c = mix(vec3(0.0), vec3(0.55, 0.06, 0.01), smoothstep(0.0, 0.25, f));
    c = mix(c, vec3(1.0, 0.36, 0.05), smoothstep(0.2, 0.5, f));
    c = mix(c, vec3(1.0, 0.72, 0.25), smoothstep(0.45, 0.75, f));
    return mix(c, vec3(1.0, 0.95, 0.80), smoothstep(0.75, 1.0, f));
}

// The back wall: firebrick in running bond, sooty higher up, lit by the
// fire at x (screen heights from the left), flickering by fl.
vec3 wall(vec2 q, float x, float fl) {
    vec2 b = q / vec2(0.15, 0.05);
    float row = floor(b.y);
    b.x += 0.5 * mod(row, 2.0);
    vec2 id = vec2(floor(b.x), row), f = fract(b);
    vec2 e = min(f, 1.0 - f) * vec2(0.15, 0.05);
    float mortar = 1.0 - smoothstep(0.002, 0.005, min(e.x, e.y));
    vec3 brick = vec3(0.42, 0.22, 0.14) * mix(0.6, 1.1, hash2(id));
    brick *= mix(0.75, 1.0, noise(q * 90.0));
    vec3 col = mix(brick, vec3(0.30, 0.26, 0.22), mortar);
    col *= mix(1.0, 0.35, smoothstep(0.3, 1.0, q.y));  // soot
    float d = length((q - vec2(x, 0.25)) * vec2(0.8, 1.2));
    float light = fl * (0.12 + 1.5 * exp(-2.2 * d));
    return col * light * vec3(1.0, 0.55, 0.28);
}

// Log from a to b, r thick, over col: dark bark split by glowing cracks,
// glowing most underneath. A broken log ends at b in jagged splinters,
// burning hot inside. Around it, a soft shadow falls on what is behind.
vec3 burning(vec3 col, vec2 q, vec2 a, vec2 b, float r, float seed, bool broken, float t, float fl) {
    vec2 ab = b - a;
    float len = length(ab);
    vec2 dir = ab / len, n = vec2(-dir.y, dir.x);
    float along = dot(q - a, dir), v = dot(q - a, n) / r;  // v: -1 underneath to 1 on top
    if (abs(v) > 1.4 || along < -1.4 * r || along > len + 1.4 * r) return col;
    float cap = r * sqrt(max(0.0, 1.0 - v * v));
    float end = len + (broken ? r * (0.1 + 0.7 * noise(vec2(v * 4.0 + seed, seed))) : cap);
    float px = 0.003;
    float on = (1.0 - smoothstep(r - px, r, abs(v) * r))
             * smoothstep(-cap - px, -cap, along) * (1.0 - smoothstep(end - px, end, along));
    float d = length(q - a - dir * clamp(along, 0.0, len)) / r;
    float shade = (1.0 - smoothstep(1.0, 1.35, d)) * (broken ? step(along, len) : 1.0);
    col *= 1.0 - 0.5 * shade;
    if (on <= 0.0) return col;
    float u = along / r;                           // along it, in radii
    float bark = noise(vec2(u * 1.5 + seed, v * 12.0));
    vec3 wood = mix(vec3(0.035, 0.025, 0.02), vec3(0.13, 0.085, 0.055), bark);
    wood *= 0.45 + 0.55 * sqrt(max(0.0, 1.0 - v * v));
    // Cracks: the ridges of a noise stretched along the log, glowing
    // where it has burnt through, most of all underneath.
    float ridge = 1.0 - abs(2.0 * noise(vec2(u * 2.2 + seed, v * 5.0)) - 1.0);
    float burnt = 1.0 - smoothstep(-0.9, 0.5, v) + 0.35 * noise(vec2(u * 0.7 - seed, 3.0));
    float glow = smoothstep(0.86, 0.98, ridge) * clamp(burnt, 0.0, 1.0);
    glow += 0.35 * (1.0 - smoothstep(-1.0, -0.6, v));  // the coals' glow from below
    glow *= 0.7 + 0.5 * noise(vec2(u * 0.8 + seed, t * 0.9));
    wood += flame(0.3 + 0.4 * glow) * glow * fl;
    // Rim light from the flames above.
    wood += vec3(0.45, 0.16, 0.03) * smoothstep(0.75, 1.0, v) * fl * 0.2;
    if (broken) {
        // The broken end, burning through: hottest at the heart of the
        // wood, cooling back along the log, and pulsing as it breathes.
        float from = (end - along) / r;
        float heat = exp(-0.7 * from) * (0.55 + 0.45 * (1.0 - v * v));
        heat *= 0.75 + 0.4 * noise(vec2(from * 3.0 + seed, t * 1.3));
        wood = mix(wood, flame(0.45 + 0.5 * heat) * fl, smoothstep(0.08, 0.5, heat));
    }
    return mix(col, wood, on);
}

// How hot the flames are at q, 0 to 1, rising in tongues from a base at
// height y0 around x, w wide each way and reaching up to about tall.
float flames(vec2 q, float x, float y0, float w, float tall, float t) {
    vec2 p = vec2(q.x - x, q.y - y0);
    float across = p.x / w;
    if (abs(across) > 1.2 || p.y < -0.06 || p.y > 1.3 * tall + 0.1) return 0.0;
    // Rising noise, warped sideways so the tongues lick and sway.
    vec2 s = vec2(p.x * 6.0, p.y * 2.6 - t * 1.8);
    s.x += 1.2 * (noise(vec2(s.x * 0.5, s.y * 0.7)) - 0.5) * (0.3 + p.y * 3.0);
    float n = fbm(s);
    float tongues = 0.6 * noise(vec2(p.x * 8.0, -t * 0.6)) + 0.4 * noise(vec2(p.x * 19.0, -t * 1.1));
    float height = max(0.15 * tall + tall * tongues * max(1.0 - across * across, 0.0), 0.01);
    float f = (1.0 - p.y / height) * 1.2 - (n - 0.5) * 1.5;
    f *= (1.0 - smoothstep(0.75, 1.15, abs(across))) * smoothstep(-0.06, 0.02, p.y);
    return clamp(f, 0.0, 1.0);
}

// Sparks: specks thrown up off the logs, drifting and winking out.
vec3 sparks(vec2 q, float x, float t) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < SPARKS; i++) {
        float n = float(i);
        float life = mix(2.5, 5.0, hash(n + 1.0));
        float run = t / life + hash(n + 2.0);
        float lap = floor(run), age = fract(run);
        if (hash3(vec3(n, lap, 4.0)) < 0.35) continue;  // not every lap
        vec2 o = vec2(x + (hash3(vec3(n, lap, 1.0)) - 0.5) * 0.6, i % 4 == 0 ? 0.08 : 0.25);
        float rise = mix(0.35, 0.8, hash3(vec3(n, lap, 2.0)));
        float sway = (hash3(vec3(n, lap, 3.0)) - 0.5) * 0.25;
        vec2 at = o + vec2(sway * age + 0.02 * sin(age * 9.0 + n), rise * age);
        float d = length(q - at);
        float bright = (1.0 - age) * (1.0 - age) * (0.6 + 0.4 * sin(t * 20.0 + n * 3.0));
        col += vec3(1.0, 0.6, 0.2) * bright * (1.0 - smoothstep(0.0, 0.004, d) + 0.25 * (1.0 - smoothstep(0.0, 0.015, d)));
    }
    return col;
}

// The hearth at q (screen heights, up from the bottom left), as recorded.
vec3 hearth(vec2 q, float aspect, float t) {
    float x = max(aspect - FIRE_RIGHT, 0.5 * aspect);
    float fl = flicker(t);
    vec3 col = wall(q, x, fl);
    // The firebox floor, ash with embers glowing through.
    float floor0 = 0.12;
    if (q.y < floor0) {
        float near = exp(-3.0 * abs(q.x - x));
        vec3 ash = vec3(0.10, 0.09, 0.08) * (0.4 + 0.6 * noise(q * 60.0)) * (0.3 + near * fl);
        float ember = smoothstep(0.6, 0.9, noise(q * vec2(110.0, 160.0) + vec2(0.0, t * 0.15)));
        ash += flame(0.3 + 0.35 * ember) * ember * near * near * fl * smoothstep(0.0, floor0, q.y);
        col = mix(ash, col, smoothstep(floor0 - 0.004, floor0, q.y));
    }
    // The broken log's glow, spilling over the floor and the logs behind.
    vec2 brk = vec2(x, 0.065);
    col += vec3(1.0, 0.42, 0.10) * 0.7 * fl * exp(-length((q - brk) * vec2(1.0, 1.5)) / 0.08);
    col += flame(flames(q, x, 0.16, 0.38, 0.62, t)) * 0.85;
    // A log lying at the back, two crossed in front of it, and in front
    // of them all one broken in two, its halves meeting in a shallow V.
    col = burning(col, q, vec2(x - 0.44, 0.13), vec2(x + 0.40, 0.155), 0.05, 1.0, false, t, fl);
    col = burning(col, q, vec2(x - 0.38, 0.09), vec2(x + 0.25, 0.34), 0.045, 7.0, false, t, fl);
    col = burning(col, q, vec2(x + 0.34, 0.09), vec2(x - 0.19, 0.33), 0.048, 13.0, false, t, fl);
    col += flame(flames(q, x, 0.05, 0.1, 0.22, t + 3.0)) * 0.9;
    col = burning(col, q, vec2(x - 0.47, 0.08), vec2(x - 0.05, 0.06), 0.042, 19.0, true, t, fl);
    col = burning(col, q, vec2(x + 0.43, 0.075), vec2(x + 0.05, 0.058), 0.04, 23.0, true, t, fl);
    // Flames lapping in front of the logs, and the brightest, hottest
    // ones on top.
    float f = flames(q, x, 0.33, 0.3, 0.5, t + 7.0);
    col += flame(0.85 * f) * smoothstep(0.65, 1.0, f) * 0.5;
    return col + sparks(q, x, t);
}

// A 5x7 font, one bit per dot, each row read left to right: x holds rows
// 0-3 and y rows 4-6, top row in the high bits.
const int GLYPHS = 21;
const ivec2 GLYPH[GLYPHS] = ivec2[GLYPHS](
    ivec2(476789, 26158),   // 0
    ivec2(143492, 4238),    // 1
    ivec2(476194, 4383),    // 2
    ivec2(1017986, 1582),   // 3
    ivec2(72018, 31810),    // 4
    ivec2(1033153, 1582),   // 5
    ivec2(205342, 17966),   // 6
    ivec2(1016900, 8456),   // 7
    ivec2(476718, 17966),   // 8
    ivec2(476719, 1100),    // 9
    ivec2(1001009, 17982),  // 10 D
    ivec2(1032734, 16927),  // 11 E
    ivec2(476688, 16942),   // 12 C
    ivec2(1001022, 16912),  // 13 P
    ivec2(541200, 16927),   // 14 L
    ivec2(476735, 17969),   // 15 A
    ivec2(574788, 4228),    // 16 Y
    ivec2(585397, 17969),   // 17 M
    ivec2(12672, 12672),    // 18 :
    ivec2(549790, 29456),   // 19 play
    ivec2(0, 0)             // 20 space
);
const int D = 10, E = 11, C = 12, P = 13, L = 14, A = 15, Y = 16, M = 17, COLON = 18, PLAY = 19, SP = 20;

// Whether glyph g has a dot at cell point p (0 to 1 each way, y down);
// the 5x7 grid sits in a 6x9 one, leaving space after it and below.
float glyph(int g, vec2 p) {
    vec2 gp = p * vec2(6.0, 9.0) - vec2(0.0, 1.0);
    if (gp.x < 0.0 || gp.y < 0.0 || gp.x >= 5.0 || gp.y >= 7.0) return 0.0;
    int r = int(gp.y);
    int row = r < 4 ? GLYPH[g].x >> ((3 - r) * 5) : GLYPH[g].y >> ((6 - r) * 5);
    return float((row >> (4 - int(gp.x))) & 1);
}

// Text: whether point q, in a line of characters starting at o with
// cells of size cell (y down from the top of the line), is in character
// i's dots.
int textCell(vec2 q, vec2 o, vec2 cell, int n, out vec2 f) {
    vec2 c = (q - o) / cell;
    c.y = -c.y;
    f = fract(c);
    if (c.y < 0.0 || c.y >= 1.0 || c.x < 0.0 || c.x >= float(n)) return -1;
    return int(c.x);
}

// A number's digit k from the left, of w digits.
int digit(int v, int k, int w) {
    for (int i = 0; i < 8; i++) if (i < w - 1 - k) v /= 10;
    return v - (v / 10) * 10;
}

// The camcorder's date stamp, in the bottom right corner: the date over
// the time, ticking on from CLOCK.
float stamp(vec2 q, float aspect, float t) {
    vec2 cell = vec2(0.024, 0.036);
    float mins = CLOCK + floor(t / 60.0);
    int day = 24 + int(mins / 1440.0);
    mins = mod(mins, 1440.0);
    int hour = int(mins / 60.0), minute = int(mod(mins, 60.0));
    int h12 = hour % 12 == 0 ? 12 : hour % 12;
    vec2 f;
    int i = textCell(q, vec2(aspect - 0.06 - 11.0 * cell.x, 0.06 + 2.0 * cell.y), cell, 11, f);
    int g = -1;
    if (i >= 0) {
        // DEC 24 1989
        int month[4] = int[4](D, E, C, SP);
        if (i < 4) g = month[i];
        else if (i < 6) g = digit(day > 31 ? 1 : day, i - 4, 2);
        else if (i == 6) g = SP;
        else g = digit(YEAR, i - 7, 4);
    } else {
        // 11:40 PM, right-aligned under it
        i = textCell(q, vec2(aspect - 0.06 - 8.0 * cell.x, 0.06 + cell.y), cell, 8, f);
        if (i == 0) g = h12 < 10 ? SP : 1;
        else if (i == 1) g = h12 % 10;
        else if (i == 2) g = COLON;
        else if (i == 3 || i == 4) g = digit(minute, i - 3, 2);
        else if (i == 5) g = SP;
        else if (i == 6) g = hour < 12 ? A : P;
        else if (i == 7) g = M;
    }
    return g < 0 ? 0.0 : glyph(g, f);
}

// The VCR's own PLAY, top right, for the first few seconds: crisp, since
// it isn't on the tape.
float play(vec2 q, float aspect, float t) {
    if (t > 6.0) return 0.0;
    vec2 f, cell = vec2(0.03, 0.045);
    int i = textCell(q, vec2(aspect - 0.07 - 6.0 * cell.x, 0.93), cell, 6, f);
    int word[6] = int[6](P, L, A, Y, SP, PLAY);
    return i < 0 ? 0.0 : glyph(word[i], f);
}

vec3 yiq(vec3 c) {
    return mat3(0.299, 0.596, 0.211, 0.587, -0.274, -0.523, 0.114, -0.322, 0.312) * c;
}
vec3 rgb(vec3 c) {
    return mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703) * c;
}

// The picture as the tape plays it back, at q.
vec3 tape(vec2 q, float aspect, float t) {
    float frame = floor(t * 30.0);
    float line = floor((1.0 - q.y) * LINES);
    // Each line wavers a little, and the head switch tears the bottom few.
    float shift = (noise(vec2(line * 0.08, t * 0.8)) - 0.5) * 0.004;
    shift += (hash2(vec2(line, frame)) - 0.5) * 0.0012;
    float tear = 1.0 - smoothstep(0.0, 0.03, q.y);
    shift += tear * (0.03 + 0.02 * hash2(vec2(frame, 1.0)));
    // Now and then a band of mistracking rolls up the picture.
    float roll = t / 40.0;
    float band = fract(roll) * 1.4 - 0.2;
    float inBand = hash3(vec3(floor(roll), 2.0, 5.0)) < 0.6 ? 1.0 - smoothstep(0.0, 0.05, abs(q.y - band)) : 0.0;
    shift += inBand * (noise(vec2(line * 0.5, t * 5.0)) - 0.3) * 0.02;

    vec2 at = vec2(q.x - shift, 1.0 - (line + 0.5) / LINES);
    vec3 pic = hearth(at, aspect, t);
    vec3 smear = hearth(at - vec2(BLEED, 0.0), aspect, t);
    // The date stamp, with a dark edge to keep it clear over the fire.
    vec2 dot1 = vec2(1.0 / LINES);
    float ink = stamp(at, aspect, t);
    float rim = max(max(stamp(at + dot1, aspect, t), stamp(at - dot1, aspect, t)),
                    max(stamp(at + vec2(dot1.x, -dot1.y), aspect, t), stamp(at - vec2(dot1.x, -dot1.y), aspect, t)));
    pic = mix(pic, vec3(0.0), max(rim - ink, 0.0) * 0.75);
    pic = mix(pic, vec3(1.0, 0.62, 0.20), ink);
    smear = mix(smear, vec3(1.0, 0.62, 0.20), stamp(at - vec2(BLEED, 0.0), aspect, t));

    // Sharp brightness, smeared color, a little faded and warm.
    vec3 c = vec3(yiq(pic).x, yiq(mix(pic, smear, 0.6)).yz * 1.15);
    c.x = c.x * 0.92 + 0.025;
    // Scanlines, tape grain, the mistracking's streaks and the tear's static.
    float within = fract((1.0 - q.y) * LINES);
    c.x *= 0.82 + 0.18 * sin(within * 3.1416);
    c.x += (hash3(vec3(floor(q * vec2(LINES * 1.5, LINES)), frame)) - 0.5) * 0.05;
    float streak = step(0.97, hash2(vec2(floor(q.x * 40.0 + hash2(vec2(line, frame)) * 9.0), line + frame)));
    c.x += (inBand * streak + tear * step(0.8, hash2(vec2(floor(q.x * 200.0), line + frame)))) * 0.35;
    c = rgb(c);

    // The VCR's PLAY, with its dark edge.
    vec2 px = vec2(1.0 / LINES);
    float on = play(q, aspect, t), edge = max(play(q + px, aspect, t), play(q - px, aspect, t));
    c = mix(c, vec3(0.0), max(edge - on, 0.0) * 0.8);
    c = mix(c, vec3(0.92, 0.95, 1.0), on);

    // A soft vignette.
    vec2 v = (q - vec2(0.5 * aspect, 0.5)) / vec2(aspect, 1.0);
    return max(c, 0.0) * (1.0 - 0.6 * dot(v, v));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    // q runs up from the bottom, in screen heights, whichever way
    // Ghostty's y runs.
    float aspect = iResolution.x / iResolution.y;
    vec2 q = (Y_DOWN ? vec2(fragCoord.x, iResolution.y - fragCoord.y) : fragCoord) / iResolution.y;

    vec3 pic = tape(q, aspect, iTime);

    // 1 on the background, fading to 0 as the pixel moves away from it.
    float mask = 1.0 - smoothstep(0.02, 0.2, distance(term.rgb, iBackgroundColor));

    fragColor = vec4(term.rgb + (pic - iBackgroundColor) * STRENGTH * mask, term.a);
}
