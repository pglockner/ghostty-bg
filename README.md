# ghostty-bg

Switches [Ghostty](https://ghostty.org)'s background between images,
gradients and animated scenes, from the command line or an fzf picker with
color previews. Gradients and scenes are custom shaders that tint only the
theme's background color, so text stays as it is. Over a bright gradient,
ghostty-bg also lightens the theme's dim text colors just enough to stay
readable. A running Ghostty 1.3 or later reloads by itself after each switch.

Runs on macOS and Linux.

## Install

```sh
git clone git@github.com:pglockner/ghostty-bg.git ~/projects/ghostty-bg
ln -s ~/projects/ghostty-bg/bin/ghostty-bg ~/.local/bin/ghostty-bg
```

Then add this line to Ghostty's config, so it picks up the background:

```
config-file = ?~/.config/ghostty-bg/ghostty-bg.conf
```

Needs fzf for the picker (`-p`) and ImageMagick for importing images and
`--png`; everything else works without them.

## Use

- `ghostty-bg` lists the backgrounds; `ghostty-bg -p` picks one in fzf, where
  ctrl-t tries one without leaving the picker.
- `ghostty-bg NAME` switches to a gradient, scene or image; `-o N` sets its
  opacity (remembered per background), `-a` animates a gradient, `-r` and
  `-R` go back to the starting opacities.
- `ghostty-bg FILE` copies an image in; `--png GRADIENT` saves a gradient as
  an image for apps that take one (atrium, iTerm2).

`ghostty-bg -h` has the details.

State lives in `~/.config/ghostty-bg/`: `ghostty-bg.conf` (what Ghostty
includes), `shaders/`, `opacity` and `backgrounds/`, the images. Set
`GHOSTTY_BG_IMAGES` to keep images in another folder, or make
`backgrounds/` a link to one, to sync them between machines.

## Develop

`scripts/test.sh` lints the script and runs it against a throwaway config
folder. Scenes are GLSL files in `scenes/`; adding one adds a scene.

Most gradients come from WezTerm's presets, which are the
[colorgrad](https://github.com/mazznoer/colorgrad-rs) crate's ports of
[d3-scale-chromatic](https://github.com/d3/d3-scale-chromatic)'s schemes
(ColorBrewer and matplotlib's viridis family).
