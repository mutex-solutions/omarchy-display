# Changelog

## 0.3.3

Fix the drag itself, which 0.3.2 got wrong in two places.

- **The Deck page lives inside a ScrollView, and its flickable stole the
  drag** as soon as the pointer moved. The display never followed the pointer.
  The monitor MouseArea now sets `preventStealing`, and so does the brightness
  slider.
- **Qt's `drag.target` was replaced with explicit pointer-delta movement.**
  The built-in drag moves the item from the pointer delta, and depending on
  handler ordering it could overwrite the snapped position after `moveDrag`
  had computed it. The pointer delta is applied, the snap is computed, and the
  snapped position is what stays.
- Verified in the running shell with a simulated drag: the item moves to the
  snapped position, both guides render, and the status reports
  `corner · flush right → DP-1 · bottom edges → DP-1` with the exact drop
  coordinates.

## 0.3.2

The free-drag interaction from the Deck mock, ported into the panel.

- **Complete-placement snapping** replaces the per-axis snap. A candidate is a
  whole placement relative to another display, so a snap always produces a
  touching layout instead of aligning an edge at a distance.
- **Tolerances**: edge 12 screen px, corner 8, centre line 5. A corner is two
  edge-type alignments; a centred line uses its own tighter limit so it cannot
  steal an edge connection on displays of different sizes.
- **Corner to corner**, including the diagonal placement where two corners
  meet. Corner contact counts as attached.
- **Guides** at the matched lines and a marker where they cross, plus a status
  row with the alignment and the exact coordinates.
- **Hysteresis**: hold 1.5x for 160 ms, with a timer so a held snap releases
  even if the pointer stops moving. A shaky hand cannot knock it loose.
- **Minimum overlap** at the ends of an edge, so the strip just past an edge
  still connects instead of doing nothing.
- **Invalid layout** strip: a display that shares no edge or corner, or an
  overlap, is reported rather than silently accepted.
- The eight preset boxes are gone; dragging with guides is the whole
  placement control.
- Preview fit reserves half a display of drag room on each side, which suits
  the narrow panel.

## 0.3.1

Free placement.

- **Drag any display** in the layout preview and drop it anywhere. The drop is
  sent as an exact logical-pixel position, so this is not limited to the eight
  presets.
- Snapping: within about 8 screen pixels of another screen's edge or centre
  line, the drop aligns to it; elsewhere it lands exactly where released.
- A dragged screen that overlaps another is outlined in the urgent colour.
  Hyprland accepts overlaps at runtime, so this warns rather than blocks; a
  drop still applies.
- The preview is taller, so a drag resolves to a finer logical position (the
  scale is set by the shortest axis).
- Boxes remain for exact edge and corner presets. Click-without-drag selects a
  screen.
- The preview no longer fights the drag: position bindings are suspended while
  dragging and re-applied from what Hyprland reports after the round trip.

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
