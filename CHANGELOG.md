# Changelog

## 0.3.0

Spatial placement and windows.

- **Eight placement boxes** around the reference monitor replace the four
  Left / Right / Above / Below buttons: four edge boxes and four corners.
  Edge boxes centre the target on the edge, corner boxes place it diagonally
  outside the corner. A box a monitor already occupies is not drawn.
- **Move** sends the focused window to the other monitor, through the
  workspace that monitor is showing.
- **Swap screens** swaps the two monitors' active workspaces, moving every
  window between them at once. Hyprland has no primary-output flag, so this is
  the practical primary/secondary control.
- Window actions do not rewrite the layout file: they do not change the
  arrangement.
- `hl.dsp.*` calls are dispatchers and must be run through `hl.dispatch()`
  after being constructed. `hl.monitor()` rules are applied directly. That
  difference is why the two paths look different in `State.qml`.

## 0.2.0

Multi-monitor arrangement.

- **Layout preview** to scale, in scaled logical pixels, with every enabled
  output drawn where Hyprland has it. Click a monitor to select it.
- **Position** moves the selected monitor left, right, above or below the
  others through Hyprland's `auto-*` positions, so the geometry is computed by
  the compositor instead of assumed by the plugin.
- **Displays** list: mode and refresh per output, plus an on/off switch.
- **Mirror** the selected output onto another one.
- The arrangement is written to `~/.config/deck/monitors.lua` after every
  change. Hyprland forgets a live rule on reload, so this file is the way to
  keep it; the README shows the one-line `dofile` to add to `monitors.lua`.
- A tap on a Deck tile with no toggle now opens the page instead of doing
  nothing. Display uses this: it has no single on/off.

## 0.1.0

First release.

- Standalone Omarchy bar widget and Deck section: brightness and refresh rate.
- Brightness through brightnessctl; refresh through Hyprland's monitor command,
  with the 60 Hz option offered only when the display actually advertises one.
- No helper script: state is read from brightnessctl and hyprctl directly.
