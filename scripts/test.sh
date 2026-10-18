#!/usr/bin/env bash
# Checks ghostty-bg: lints it (bash -n, then shellcheck if installed), then
# runs it with its state in a throwaway folder and checks what it writes:
# its config, the shader, the remembered opacities and exported images.
# Ghostty is left alone: its config doesn't include the throwaway one, so
# ghostty-bg doesn't signal it. The picker (-p) is interactive and not
# covered, beyond its preview pane. Needs ImageMagick; compiles the shaders
# too if glslangValidator is installed, and checks the text-color fitting
# if Ghostty is. Exits non-zero if any check fails.
set -euo pipefail
cd "$(dirname "$0")/.."

bash -n bin/ghostty-bg scripts/test.sh
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning bin/ghostty-bg scripts/test.sh
else
    echo "skip  shellcheck (not installed)"
fi

# A template with X's works with both macOS's and GNU's mktemp.
work="$(mktemp -d "${TMPDIR:-/tmp}/test-ghostty-bg.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"   # --png saves under ~/Pictures
export XDG_CONFIG_HOME="$work/config"
state="$XDG_CONFIG_HOME/ghostty-bg"
conf="$state/ghostty-bg.conf"
shaders="$state/shaders"
opacities="$state/opacity"
# The theme the text-color checks read: a dark one, and with light, a light
# one.
export GHOSTTY_BG_THEME_NAME='Fish Tank'
mkdir -p "$HOME" "$state/backgrounds"

im() { if command -v magick >/dev/null 2>&1; then magick "$@"; else convert "$@"; fi; }
im -size 64x40 gradient:navy-teal "$state/backgrounds/sample.jpg"

bg() { bin/ghostty-bg "$@"; }
has() { grep -q -- "$2" "$1"; }   # FILE PATTERN
lacks() { ! grep -q -- "$2" "$1"; }
fails() { ! "$@"; }
says() { bg "$1" | grep -q -- "$2"; }   # NAME TEXT: switching to NAME prints TEXT
previews() { bg --preview "$1" | grep -q -- "$2"; }   # NAME TEXT
warns() { bg "$@" | grep -q 'readable up to'; }   # ARGS: switching warns it's too strong
light() { GHOSTTY_BG_THEME_NAME='Atom One Light' "$@"; }   # COMMAND...: run it over a light theme
empty() { [ -z "$(ls -A "$1")" ]; }   # DIR
pixel() { im "$1" -format "%[hex:p{$2}]" info:; }   # FILE X,Y
# awk functions for the color checks. Colors are "#rrggbb": ch(c, i) is
# the channel starting at i (2, 4 or 6), lum(c) the luminance in linear
# light, as the readability math measures it.
COLOR_AWK='
    function hx(c, i) { return index("0123456789abcdef", tolower(substr(c, i, 1))) - 1 }
    function ch(c, i) { return hx(c, i) * 16 + hx(c, i + 1) }
    function lin(c, i) { v = ch(c, i) / 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
    function lum(c) { return 0.2126 * lin(c, 2) + 0.7152 * lin(c, 4) + 0.0722 * lin(c, 6) }
'
# Palette 4 (blue) in the config is lighter than the theme's #525fb8 and
# still has more blue in it than red or green.
blue_still_blue() {
    sed -n 's/^palette = 4=//p' "$conf" | awk "$COLOR_AWK"'{
        exit !(ch($1, 6) > ch($1, 2) && ch($1, 6) > ch($1, 4) && lum($1) > lum("#525fb8")) }'
}
# Palette 3 (yellow) in the config is darker than the light theme's #d2b67c.
yellow_darkened() {
    sed -n 's/^palette = 3=//p' "$conf" | awk "$COLOR_AWK"'{ exit !(lum($1) < lum("#d2b67c")) }'
}

# Every preset in bin/ghostty-bg is angled 135 (top left to bottom right)
# and its last color is at least as bright as its first.
bright_corner() {
    sed -n "/^PRESETS='/,/'\$/p" bin/ghostty-bg | sed "s/^PRESETS='//; s/'\$//" | awk "$COLOR_AWK"'
        { m = 0; for (i = 3; i <= NF; i++) if ($i ~ /^#/) c[++m] = $i
          if ($2 != 135 || lum(c[m]) < lum(c[1])) { print "wrong way round: " $1; bad = 1 } }
        END { exit bad }'
}

# The shader with a stand-in for the header Ghostty puts in front of it.
compiles() {
    {
        printf '%s\n' '#version 430 core' \
            'layout(binding = 1, std140) uniform Globals { vec3 iResolution; float iTime; vec3 iBackgroundColor; };' \
            'layout(binding = 0) uniform sampler2D iChannel0;' 'layout(location = 0) out vec4 _fragColor;' \
            'void mainImage(out vec4 fragColor, in vec2 fragCoord);' \
            'void main() { mainImage(_fragColor, gl_FragCoord.xy); }'
        cat "$shaders"/*.glsl
    } >"$work/check.frag"
    glslangValidator -G "$work/check.frag" -o /dev/null
}

failed=0
# check DESCRIPTION COMMAND...: run COMMAND quietly and report whether it held.
check() {
    local what=$1
    shift
    if "$@" >/dev/null 2>&1; then
        echo "ok    $what"
    else
        echo "FAIL  $what"
        failed=$((failed + 1))
    fi
}
glsl() {
    if command -v glslangValidator >/dev/null 2>&1; then check "$1" compiles; else echo "skip  $1 (no glslangValidator)"; fi
}

check "a config Ghostty doesn't include says how to add it" says ember "doesn't include"
check "every gradient runs to its brighter end at the bottom right" bright_corner

bg orchid >/dev/null
check "a gradient starts at its preset's opacity" test -e "$shaders/orchid-0.7.glsl"
check "a still gradient isn't animated" has "$conf" '^custom-shader-animation = false$'

bg -a thermal >/dev/null
check "a five-color preset gives a five-color shader" has "$shaders/thermal-0.3-animated.glsl" '^const int N = 5;$'
glsl "an animated five-color shader compiles"

bg -a sunset >/dev/null
bg -o 0.4 >/dev/null
check "changing only the opacity keeps the animation" test -e "$shaders/sunset-0.4-animated.glsl"
check "-o is remembered" has "$opacities" '^sunset 0.4$'
bg -o .4 ocean >/dev/null
check "an opacity typed as .4 is 0.4, so it names the same shader" test -e "$shaders/ocean-0.4.glsl"
bg -r ocean >/dev/null
check "-r goes back to the starting opacity" test -e "$shaders/ocean-0.25.glsl"
check "-r forgets the remembered opacity" lacks "$opacities" '^ocean '
bg -o 0.5 orchid >/dev/null
bg -o 0.6 sample >/dev/null
bg -R >/dev/null
check "-R forgets every remembered opacity" fails test -s "$opacities"
check "-R puts the active background back at its own" has "$conf" '^background-image-opacity = 0.25$'

bg sample >/dev/null
check "an image clears the shader" empty "$shaders"
check "an image drops the shader lines" lacks "$conf" '^custom-shader'
check "an image is named in the config" has "$conf" '^background-image = .*/sample.jpg$'
mkdir -p "$work/elsewhere"
im -size 64x40 gradient:black-maroon "$work/elsewhere/other.jpg"
GHOSTTY_BG_IMAGES="$work/elsewhere" bg other >/dev/null
check "GHOSTTY_BG_IMAGES points at another image folder" has "$conf" "^background-image = .*/elsewhere/other.jpg$"

bg jellyfish >/dev/null
check "leaving an image drops its opacity line" lacks "$conf" '^background-image'
check "a scene gets its strength put in front" has "$shaders/jellyfish-0.25.glsl" '^const float STRENGTH = 0.250;$'
check "a scene is animated" has "$conf" '^custom-shader-animation = true$'
glsl "a scene compiles"

# Lifting dim text reads the theme through Ghostty itself.
if command -v ghostty >/dev/null 2>&1 || [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
    bg glacier >/dev/null
    check "a pale gradient lifts the dim palette colors" has "$conf" '^palette = 4=#'
    check "a lifted color keeps its hue (blue stays bluest)" blue_still_blue
    bg jellyfish >/dev/null
    check "a scene drops the lifted colors" lacks "$conf" '^palette'
    bg orchid >/dev/null
    check "a deep gradient leaves the palette alone" lacks "$conf" '^palette'
    check "a gradient past its readable opacity warns" warns -o 1 wildfire
    check "a deep gradient at full opacity doesn't warn" fails warns -o 1 velvet
    light bg orchid >/dev/null
    check "a deep gradient on a light theme darkens its pale colors" yellow_darkened
    check "a deep gradient on a light theme warns past its readable opacity" light warns -o 1 velvet
    check "a light theme's foreground needs full contrast (orchid warns at 0.7)" light warns -o 0.7 orchid
    light bg -r orchid >/dev/null
    check "a deep gradient on a light theme starts at its readable opacity" has "$conf" '/orchid-0\.5\.glsl$'
    check "a deep gradient on a light theme raises faint-opacity" has "$conf" '^faint-opacity = 0\.[6-9]'
    bg jellyfish >/dev/null
    check "a scene drops the raised faint-opacity" lacks "$conf" '^faint-opacity'
else
    echo "skip  text-color lifting and readability warnings (no Ghostty)"
fi

bg orchid >/dev/null
cp "$conf" "$work/before.conf"
bg --png orchid >/dev/null
png="$HOME/Pictures/ghostty-bg/orchid.png"
check "--png leaves the background alone" cmp -s "$conf" "$work/before.conf"
check "--png renders 3840x2160" test "$(im "$png" -format '%wx%h' info:)" = 3840x2160
check "--png starts at the first color" test "$(pixel "$png" 0,0)" = 6A1B6E
check "--png ends at the last color" test "$(pixel "$png" 3839,2159)" = 0D4A8A
check "--png refuses an image" fails bg --png sample

check "an unknown name fails" fails bg nope
check "an opacity over 1 fails" fails bg -o 2 orchid
check "the picker previews a gradient's colors" previews orchid '#6a1b6e #3b1f8a #0d4a8a'
check "the picker previews a scene's description" previews jellyfish 'Sea nettles'
check "a scene's preview leaves out the copying note" fails previews jellyfish 'ghostty-bg puts'

if [ "$failed" -gt 0 ]; then
    echo "$failed failed"
    exit 1
fi
echo "all passed"
