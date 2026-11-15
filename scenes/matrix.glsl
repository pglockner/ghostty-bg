// Slow, muted Matrix code: strings of mirrored katakana dropping down the
// screen, each led by a pale head and fading behind it, every character
// drawn in smooth strokes through the dots of a 5x7 bitmap. The code falls
// in planes: the front one glows softly, and behind it smaller, slower,
// dimmer and sparser ones give the screen depth. ghostty-bg puts
// `const float STRENGTH` (the opacity), `const bool Y_DOWN` (whether
// fragCoord's y runs down the screen), and screen_at and to_screen (the
// screen's colors as stored, and back) in front of this file.

const vec2 CELL = vec2(21.0, 27.0);  // pixels per character, in the front plane
const vec2 DOTS = vec2(7.0, 9.0);    // dots per character: a 5x7 glyph and a dot of space all round
const float SPEED = 1.0;             // cells per second, roughly, in the front plane
const vec3 TRAIL = vec3(0.20, 0.75, 0.40);
const vec3 HEAD = vec3(0.70, 1.00, 0.80);
// Each glyph's dots are joined into strokes STROKE dots either side of
// their centerline. Around them a plane's glow reaches GLOW_REACH dots past
// the stroke's edge. STROKE + GLOW_REACH past 5 would reach cells code()
// doesn't look at.
const float STROKE = 0.45;
const float GLOW_REACH = 2.0;

// A plane of falling code: its characters `scale` times CELL, falling
// `speed` times SPEED, `bright` as bright as the front's, code in `share`
// of its columns, `strings` of them per column, and a halo `glow` as
// bright as the strokes it starts from (0 for none).
struct Plane {
    float scale, speed, bright, share;
    int strings;
    float glow;
};
const int PLANES = 3;   // each drawn by its own call in mainImage
const Plane PLANE[PLANES] = Plane[PLANES](   // front to back
    Plane(1.00, 1.0, 1.00, 1.0, 2, 0.65),
    Plane(0.75, 0.7, 0.55, 0.6, 1, 0.0),
    Plane(0.55, 0.5, 0.30, 0.5, 1, 0.0)
);

// Behind the code, the theme's background is darkened toward this gray, by
// DARKEN (0 leaves it as it is, 1 replaces it).
const vec3 BACKDROP = vec3(0.055);
const float DARKEN = 0.8;

// Katakana in a 5x7 grid, one bit per dot, each row read left to right: x
// holds rows 0-3 and y rows 4-6, top row in the high bits. They are stored
// the right way round and mirrored when drawn.
const int GLYPHS = 32;
const ivec2 GLYPH[GLYPHS] = ivec2[GLYPHS](
    ivec2(1016998, 4232),   // a
    ivec2(34956, 20612),    // i
    ivec2(163361, 1100),    // u
    ivec2(31876, 4255),     // e
    ivec2(97350, 10822),    // o
    ivec2(162975, 4228),    // ki
    ivec2(278049, 2184),    // ku
    ivec2(31777, 2016),     // ko
    ivec2(359754, 2184),    // sa
    ivec2(1016900, 10784),  // su
    ivec2(574753, 2200),    // so
    ivec2(278061, 2184),    // ta
    ivec2(94367, 4232),     // chi
    ivec2(459748, 4232),    // te
    ivec2(270730, 8456),    // to
    ivec2(136164, 4368),    // na
    ivec2(1017156, 10784),  // nu
    ivec2(10569, 17952),    // ha
    ivec2(541308, 16911),   // hi
    ivec2(1016866, 2184),   // fu
    ivec2(162965, 21636),   // ho
    ivec2(1016916, 8322),   // ma
    ivec2(135432, 19425),   // mu
    ivec2(42178, 5392),     // me
    ivec2(1020900, 4227),   // mo
    ivec2(294186, 8324),    // ya
    ivec2(1016895, 1087),   // yo
    ivec2(459745, 1100),    // ra
    ivec2(575025, 1100),    // ri
    ivec2(541200, 18012),   // re
    ivec2(32305, 18400),    // ro
    ivec2(1033761, 2184)    // wa
);

// Dave Hoskins' hash without sine (https://www.shadertoy.com/view/4djSRW,
// Copyright (c) 2014 David Hoskins, MIT License). A sine hash goes stale as its input
// grows with time (32-bit floats can't hold sin() of a large number
// precisely), and the characters' ticks grow for as long as the scene runs.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Whether a glyph, given by its GLYPH entry, has a dot at q of its cell's
// 7x9 grid (x right, y down). The 5x7 glyph sits in the middle, leaving a
// dot of space all round.
bool inked(ivec2 bits, ivec2 q) {
    q -= 1;
    if (q.x < 0 || q.y < 0 || q.x >= 5 || q.y >= 7) return false;
    int row = q.y < 4 ? bits.x >> ((3 - q.y) * 5) : bits.y >> ((6 - q.y) * 5);
    // Bit c holds column 4 - c, so reading bit x draws column x mirrored.
    return ((row >> q.x) & 1) != 0;
}

// How far p is from the line from a to b.
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// The color of the code in cell of plane pl, black where no string is
// passing. The plane's seed sets its strings apart from other planes'.
vec3 lit(vec2 cell, float rows, Plane pl, float seed) {
    if (hash(vec2(cell.x + 0.5, seed + 50.0)) >= pl.share) return vec3(0.0);
    // Each string with its own speed, length and gap.
    float trail = 0.0, head = 0.0;
    for (int k = 0; k < pl.strings; k++) {
        vec2 s = vec2(cell.x, float(k) + 2.0 * seed);
        float speed = SPEED * pl.speed * mix(0.6, 1.6, hash(s + 0.1));
        float len = mix(8.0, 26.0, hash(s + 0.2));
        float period = rows + len + mix(5.0, 40.0, hash(s + 0.3));
        float behind = floor(mod(iTime * speed + hash(s) * period, period)) - cell.y;
        if (behind >= 0.0 && behind < len) {
            trail = max(trail, pow(1.0 - behind / len, 1.6));
            if (behind < 1.0) head = 1.0;
        }
    }
    return mix(TRAIL * trail, HEAD, head);
}

// The glyph in cell. Each character changes now and then, at its own pace.
int pick(vec2 cell, float seed) {
    cell += seed * vec2(101.0, 67.0);
    float pace = mix(0.05, 0.4, hash(cell + 7.0));
    float tick = floor(iTime * pace + hash(cell + 3.0));
    return int(hash(cell + tick * 0.618) * float(GLYPHS)) % GLYPHS;
}

// The code of plane pl at pixel p (y down), seed being its place among the
// planes.
vec3 code(vec2 p, Plane pl, float seed) {
    vec2 size = CELL * pl.scale;
    vec2 cell = floor(p / size);
    float rows = iResolution.y / size.y;

    vec2 e = p / (size / DOTS) - 0.5;   // the pixel in dots, dot centers on whole numbers
    float edge = 0.5 / (size.x / DOTS.x);   // half a pixel, in dots
    // How far from a dot's center the plane shows.
    float reach = STROKE + (pl.glow > 0.0 ? GLOW_REACH : edge);

    // The glow reaches across from the neighbors on the pixel's side of
    // its cell: the one beside it, the one above or below, and the one
    // diagonally between. Index i holds the cell offset by side times
    // (i & 1, i >> 1), so 0 is the pixel's own. A neighbor is looked at
    // only when its glyph's nearest row or column of dots is within reach.
    vec2 side = 2.0 * step(0.5, fract(p / size)) - 1.0;
    vec2 nearest = cell * DOTS + mix(vec2(-2.0), DOTS + 1.0, step(0.0, side));
    bvec2 reaches = lessThanEqual(abs(nearest - e), vec2(reach));
    vec3 color[4];
    ivec2 bits[4];   // each one's GLYPH entry, read once; none where it's unlit or out of reach
    for (int i = 0; i < 4; i++) {
        vec2 c = cell + side * vec2(i & 1, i >> 1);
        bool look = ((i & 1) == 0 || reaches.x) && ((i >> 1) == 0 || reaches.y);
        color[i] = look ? lit(c, rows, pl, seed) : vec3(0.0);
        bits[i] = color[i] != vec3(0.0) ? GLYPH[pick(c, seed)] : ivec2(0);
    }
    if (bits[0] == ivec2(0) && bits[1] == ivec2(0) && bits[2] == ivec2(0) && bits[3] == ivec2(0)) return vec3(0.0);

    // How far the pixel is from the strokes of each of those cells' glyphs.
    // A lit dot joins each lit neighbor beside or below it, and a diagonal
    // one only where no dot beside or below would join them already, so
    // steps read as diagonals rather than filled corners. Only the dots of
    // a glyph's 5x7 grid that can start a stroke within reach are looked
    // at; a stroke runs right, left or down from its dot, at most one dot
    // each way.
    float far[4] = float[4](1e3, 1e3, 1e3, 1e3);
    for (int i = 0; i < 4; i++) {
        if (bits[i] == ivec2(0)) continue;
        vec2 origin = (cell + side * vec2(i & 1, i >> 1)) * DOTS;   // the cell's top left dot
        ivec2 lo = ivec2(max(ceil(e - reach - 1.0), origin + 1.0) - origin);
        ivec2 hi = ivec2(min(floor(e + vec2(reach + 1.0, reach)), origin + vec2(5, 7)) - origin);
        for (int y = lo.y; y <= hi.y; y++) {
            for (int x = lo.x; x <= hi.x; x++) {
                ivec2 l = ivec2(x, y);
                if (!inked(bits[i], l)) continue;
                vec2 a = origin + vec2(l);
                float f = length(e - a);
                // Further off, the dot alone is near enough: its strokes
                // would come at most a tenth of a dot nearer, a change in
                // the faint edge of the halo too small to see.
                if (f < 2.4) {
                    bool right = inked(bits[i], l + ivec2(1, 0));
                    bool left = inked(bits[i], l + ivec2(-1, 0));
                    bool down = inked(bits[i], l + ivec2(0, 1));
                    if (right) f = min(f, segment(e, a, a + vec2(1, 0)));
                    if (down) f = min(f, segment(e, a, a + vec2(0, 1)));
                    if (!right && !down && inked(bits[i], l + ivec2(1, 1))) f = min(f, segment(e, a, a + vec2(1, 1)));
                    if (!left && !down && inked(bits[i], l + ivec2(-1, 1))) f = min(f, segment(e, a, a + vec2(-1, 1)));
                }
                far[i] = min(far[i], f);
            }
        }
    }

    // The pixel's own glyph, its edge softened over a pixel, and around
    // every glyph within reach a halo fading smoothly from its edge.
    vec3 shown = color[0] * (1.0 - smoothstep(STROKE - edge, STROKE + edge, far[0]));
    for (int i = 0; i < 4; i++) {
        float t = clamp((far[i] - STROKE) / GLOW_REACH, 0.0, 1.0);
        shown = max(shown, color[i] * pl.glow * (1.0 - t) * (1.0 - t));
    }
    return shown;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = screen_at(uv);

    // Pixels with y running down the screen, the way the code falls,
    // whichever way Ghostty's y runs.
    vec2 p = Y_DOWN ? fragCoord : vec2(fragCoord.x, iResolution.y - fragCoord.y);

    // Where planes cross, the brighter shows. One call per plane rather
    // than a loop, so that the compiler can fit each call to its plane.
    vec3 shown = code(p, PLANE[0], 0.0) * PLANE[0].bright;
    shown = max(shown, code(p, PLANE[1], 1.0) * PLANE[1].bright);
    shown = max(shown, code(p, PLANE[2], 2.0) * PLANE[2].bright);

    // 1 on the background, fading to 0 as the pixel moves away from it.
    float mask = 1.0 - smoothstep(0.02, 0.2, distance(term.rgb, iBackgroundColor));

    vec3 base = mix(term.rgb, BACKDROP, DARKEN * mask);
    fragColor = vec4(to_screen(base + shown * STRENGTH * mask), term.a);
}
