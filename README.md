# RGB Sync for Omarchy

Your case, keyboard and mouse lighting follows your Omarchy background or theme —
automatically, every time it changes.

![RGB Sync panel](preview.png)

A palette icon in the bar shows the current LED color as a small dot. Click it to
pick the color source, tune saturation and brightness, choose a theme color and
toggle single devices. Right-click turns the lighting on or off.

## How it works

- **Background** (default): the dominant hue of the top part of your wallpaper
  (usually the sky), pushed to full saturation so LEDs don't look washed out.
- **Theme**: the hue of a color from the current theme's `colors.toml`
  (`accent` by default, or `keyboard` for the theme's `keyboard.rgb`).
- **Fixed**: one color of your choice, e.g. picked from the theme palette.

A small service runs inside `omarchy-shell` and watches
`~/.local/state/omarchy/current` with inotify. Theme switches, `omarchy theme bg next`
and logins all trigger a sync — no autostart entry, hook or extra daemon needed.

## Install

```bash
omarchy pkg add openrgb python-pillow inotify-tools
omarchy plugin add https://github.com/raimoghg/omarchy-rgb-sync.git --enable
```

The background service is mounted when the shell starts, so restart it once after
installing: `omarchy restart shell`.

OpenRGB needs access to your hardware first: make sure `openrgb -l` lists your
devices without `sudo` (see the OpenRGB docs for the i2c/udev setup on your
mainboard). On the first sync the plugin detects all listed devices.

Optional, to use the CLI from a terminal:

```bash
ln -s ~/.config/omarchy/plugins/raimoghg.rgb-sync/bin/omarchy-rgb ~/.local/bin/omarchy-rgb
```

## CLI

```bash
omarchy-rgb status | jq              # settings, last state, missing dependencies
omarchy-rgb preview                  # compute the color without applying it
omarchy-rgb set source theme         # wallpaper | theme | fixed
omarchy-rgb set themeKey color4      # any key in colors.toml, or "keyboard"
omarchy-rgb set fixedColor '#00FFAA'
omarchy-rgb set brightness 0.6
omarchy-rgb on / off
omarchy-rgb sync --force
omarchy-rgb detect                   # re-detect devices, keeps per-device settings
omarchy-rgb device 0 channelOrder RBG
omarchy-rgb device 1 enabled false
```

## Configuration

Settings live in `~/.config/omarchy/rgb-sync.json`, state in
`~/.local/state/omarchy-rgb/state.json`.

| Key | Default | |
|---|---|---|
| `source` | `wallpaper` | `wallpaper`, `theme` or `fixed` |
| `themeKey` | `accent` | color key used by the theme source |
| `fixedColor` | `#FF00AA` | color used by the fixed source |
| `saturation`, `brightness` | `1.0` | 0–1 |
| `topFraction` | `0.55` | share of the wallpaper (from the top) that is analysed |
| `fallbackHue` | `330` | hue in degrees when the image has no clear color |
| `mode` | `direct` | OpenRGB mode |
| `devices` | detected | see below |

Per device: `id` (from `openrgb -l`), `name`, `enabled`, `zones` (`[]` = whole device)
and `channelOrder`. Some boards report swapped channels — if green and blue show up
the wrong way round, set `channelOrder` to `RBG` for that device.

All devices are set in a single `openrgb` call; most of the ~5 s it takes is
OpenRGB scanning the hardware. When nothing changed the CLI returns immediately.

## License

MIT
