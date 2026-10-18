// Slow, muted Matrix code: strings of mirrored katakana dropping down the
// screen, each led by a pale head and fading behind it. ghostty-bg puts
// `const float STRENGTH` (the opacity) in front of this file.

const vec2 CELL = vec2(21.0, 27.0);  // pixels per character
const float SPEED = 1.0;             // cells per second, roughly
const vec3 TRAIL = vec3(0.20, 0.75, 0.40);
const vec3 HEAD = vec3(0.70, 1.00, 0.80);
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

// How much of glyph g covers point p of its cell (0 to 1 each way, y down).
// The 5x7 grid sits in a 7x9 one, leaving a dot of space all round.
float glyph(int g, vec2 p) {
    vec2 gp = p * vec2(7.0, 9.0) - 1.0;
    if (gp.x < 0.0 || gp.y < 0.0 || gp.x >= 5.0 || gp.y >= 7.0) return 0.0;
    int r = int(gp.y);
    int row = r < 4 ? GLYPH[g].x >> ((3 - r) * 5) : GLYPH[g].y >> ((6 - r) * 5);
    // Bit c holds column 4 - c, so reading bit x draws column x mirrored.
    float on = float((row >> int(gp.x)) & 1);
    vec2 f = abs(fract(gp) - 0.5);
    return on * (1.0 - smoothstep(0.38, 0.5, max(f.x, f.y)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    // Ghostty's y runs downward, the way the code falls.
    vec2 cell = floor(fragCoord / CELL);
    float rows = iResolution.y / CELL.y;

    // Two strings per column, each with its own speed, length and gap.
    float trail = 0.0, head = 0.0;
    for (int k = 0; k < 2; k++) {
        vec2 s = vec2(cell.x, float(k));
        float speed = SPEED * mix(0.6, 1.6, hash(s + 0.1));
        float len = mix(8.0, 26.0, hash(s + 0.2));
        float period = rows + len + mix(5.0, 40.0, hash(s + 0.3));
        float behind = floor(mod(iTime * speed + hash(s) * period, period)) - cell.y;
        if (behind >= 0.0 && behind < len) {
            trail = max(trail, pow(1.0 - behind / len, 1.6));
            if (behind < 1.0) head = 1.0;
        }
    }

    // Each character changes now and then, at its own pace.
    float pace = mix(0.05, 0.4, hash(cell + 7.0));
    float tick = floor(iTime * pace + hash(cell + 3.0));
    int g = int(hash(cell + tick * 0.618) * float(GLYPHS)) % GLYPHS;
    float ink = trail > 0.0 ? glyph(g, fract(fragCoord / CELL)) : 0.0;
    vec3 code = mix(TRAIL * trail, HEAD, head) * ink;

    // 1 on the background, fading to 0 as the pixel moves away from it.
    float mask = 1.0 - smoothstep(0.02, 0.2, distance(term.rgb, iBackgroundColor));

    vec3 base = mix(term.rgb, BACKDROP, DARKEN * mask);
    fragColor = vec4(base + code * STRENGTH * mask, term.a);
}
