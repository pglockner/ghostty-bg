#!/usr/bin/env bash
# Installs ghostty-bg from this checkout: installs fzf and ImageMagick with
# the system's package manager if they're missing, links bin/ghostty-bg into
# ~/.local/bin, and says what to add to Ghostty's config. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")/.."

# The command that installs packages with this system's package manager,
# followed by its packages' names. Fedora and openSUSE spell ImageMagick
# with capitals.
installer() {
    if command -v brew >/dev/null 2>&1; then echo brew install
    elif command -v pacman >/dev/null 2>&1; then echo sudo pacman -S --needed
    elif command -v apt-get >/dev/null 2>&1; then echo sudo apt-get install
    elif command -v dnf >/dev/null 2>&1; then echo sudo dnf install
    elif command -v zypper >/dev/null 2>&1; then echo sudo zypper install
    elif command -v apk >/dev/null 2>&1; then echo sudo apk add
    fi
}
package() {
    case "$1 $(installer)" in
        "imagemagick sudo dnf"* | "imagemagick sudo zypper"*) echo ImageMagick ;;
        *) echo "$1" ;;
    esac
}

missing=()
command -v fzf >/dev/null 2>&1 || missing+=("$(package fzf)")
command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 ||
    missing+=("$(package imagemagick)")
if [ ${#missing[@]} -gt 0 ]; then
    read -r -a cmd <<<"$(installer)"
    if [ ${#cmd[@]} -eq 0 ]; then
        echo "No package manager found; install these yourself: ${missing[*]}" >&2
    else
        echo "Installing ${missing[*]}: ${cmd[*]} ${missing[*]}"
        "${cmd[@]}" "${missing[@]}"
    fi
fi

bin="$HOME/.local/bin"
mkdir -p "$bin"
ln -sfn "$PWD/bin/ghostty-bg" "$bin/ghostty-bg"
echo "Linked $bin/ghostty-bg"
case ":$PATH:" in
    *":$bin:"*) ;;
    *) echo "Add $bin to your PATH." ;;
esac

command -v ghostty >/dev/null 2>&1 || [ -d /Applications/Ghostty.app ] ||
    echo "Ghostty isn't installed; ghostty-bg needs it."

line='config-file = ?~/.config/ghostty-bg/ghostty-bg.conf'
conf="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
if grep -qsF -- "$line" "$conf"; then
    echo "Ghostty's config already includes ghostty-bg."
else
    echo "Add this line to Ghostty's config ($conf):"
    echo "  $line"
fi
