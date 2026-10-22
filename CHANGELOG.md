# Changelog

## 0.3.22

- **Apply sends the whole arrangement in one eval.** It used to apply only the
  monitor that was moved. Moving one output next to another can make Hyprland
  shift the other out of the way, so the applied layout did not match the
  preview: the staged monitor landed, the anchor was pushed aside, and the
  page saved the corner arrangement instead of the centred one.
- The staged monitors are now followed by every anchor's final position in a
  single `hl.monitor` script. Verified from the corner layout: one eval with
  eDP-1 at 8320x1080 then DP-1 at 8000x0 produced the centred, flush-below
  arrangement.

## 0.3.21

- The Deck tile is neutral: a display has no on/off state, so it no longer
  takes the selected fill that a toggleable section uses.

## 0.3.20

- A **4x1 tile** (`tileFull`) lists each monitor with its resolution and
  refresh rate, which the 2x1 summary cannot. A tap opens the display page.

## 0.3.19

- **Window management moved out.** Moving a window and swapping screens now
  live in the Sessions section, where they belong with workspaces. The Display
  page is arrangement, resolution, refresh rate, scale, brightness and text
  size. The active-window probe and actions were removed from this plugin too.

## 0.3.18

Resolution, scale, text size, and per-monitor brightness, reusing Omarchy's
own helpers.

- **Brightness** now goes through `omarchy-brightness-display --monitor`:
  internal backlight, Apple displays and DDC/CI externally. The ASUS answers
  and accepts DDC, so the slider controls the screen it is attached to,
  including when an external display is selected. The section hides when the
  helper reports nothing controllable.
- **Resolution** picker from `availableModes`, grouped and labelled by common
  aspect ratio. Selecting applies the highest rate at that resolution
  immediately. Modes below 720p and odd aspects are filtered out; the current
  resolution is always present.
- **Scale** presets (`1, 1.25, 1.6, 2, 3, 4`) cleaned with the same gcd rule as
  `omarchy-hyprland-monitor-scaling`, applied immediately.
- **Text size** stops (9–20 px) through `omarchy-display-text-size`, which
  scales the shell, GTK and terminals together.
- The rate list uses the selected resolution; rates remain immediate.

Verified: DP-1 listed 8 resolutions (16:9, 4:3, 5:4), 6 scales and DDC
brightness 100; eDP-1 listed its single resolution, 6 scales and internal
brightness 100; current resolution, scale and text size re-applied without
error.

## 0.3.17

- Duplicate rate entry fixed. When the internal panel was already at 60 Hz,
  the current-mode entry added 60 and did not mark it as seen, so the internal
  60 Hz fallback added a second 60. The current entry now marks its rate seen;
  eDP-1 lists 60 and 120 once each.

## 0.3.16

- The confirmation row says **Pending changes** before Apply/Cancel, so a
  staged layout is named in the UI rather than implied by two buttons.

## 0.3.15

Refresh rates apply when chosen.

- A selected rate now applies immediately. It was staged, and the Apply row
  lives with the layout controls below Brightness, so from the rate dropdown
  the confirmation was off-screen and the choice looked like it did nothing.
- The rate rule uses the display's **live** position, so applying a rate can
  never also apply a staged, unconfirmed position.
- The rate control is hidden for a mirrored output, which has no independent
  rate to set.

Verified: applying 60 put eDP-1 at 60 Hz and the label followed; applying 120
restored 120.002.

## 0.3.14

Refresh rates that actually apply, and brightness on the right display.

- `availableModes` reports `WxH@RHz`, but `hl.monitor` wants `WxH@R`. Passing
  the Hz form back was silently rejected, which is why choosing a rate did
  nothing. The mode strings are normalised before they reach Hyprland.
- The XPS 13 internal panel advertises only `2560x1600@120`, so the dropdown
  had one entry. The native `2560x1600@60` mode is accepted but not
  advertised; internal panels (`eDP`, `LVDS`, `DSI`) now get a 60 Hz fallback
  at their current resolution.
- **Brightness follows the selected display.** It is shown only for an
  internal display, because brightnessctl addresses the laptop backlight and
  would move the wrong screen when an external monitor is selected.

Verified: eDP-1 lists 60 and 120 Hz; applying 60 put the live rate at 60 and
restoring 120 brought it back; DP-1 (external) hides Brightness and lists its
12 rates.

## 0.3.13

Section order by what is used most.

- **Displays** (selection, refresh rate, mirror) comes first, directly under
  the hero.
- **Brightness** follows.
- **Layout** (the drag preview and its controls) is below both, since
  selecting a monitor and setting its rate is the common action.
- **Windows** is last.
- Mirror moved inside the Displays section, next to the monitor it targets.

## 0.3.12

- The standalone panel's scrollbar is hidden. It overlaid the right edge of
  the page and blocked the controls there. Wheel and touch scrolling remain.

## 0.3.11

Control layout in the preview footer.

- The zoom controls (`Fit`, `−`, `+`) are pinned to the right edge as one
  row. Fit is inserted to the left of the zoom buttons, so showing it never
  shifts them.
- The view controls sit directly under the preview and do not move when a
  pending edit appears.
- **Apply / Cancel** have their own line below the view controls.

## 0.3.10

Collapsible sections and a real refresh-rate picker.

- **Sections are collapsible** from their header; Displays, Windows and
  Brightness each carry a chevron. The layout preview stays open.
- **Refresh rate** for the selected display, read from the compositor's
  `availableModes` at the current resolution. DP-1 advertises 12 rates here,
  including 59.94 and 159.98. The mode in use is included even when the panel
  does not advertise it, so a custom 60 Hz mode is not invisible.
- A rate choice is **staged** like a position; Apply applies mode and position
  in one `hl.monitor` rule, Cancel discards it. Selecting a monitor resets the
  open rate list.
- The Displays list shows the staged rate for a display until it is applied or
  cancelled.

## 0.3.9

Fit and refit behaviour.

- An **invalid staged layout no longer moves the view**. The fit follows the
  live arrangement plus a staged position only when the staged layout is
  valid; a detached placement cannot drag the preview out to chase it.
- Refits are **animated** (160 ms). The first fit on opening the page is not
  animated, so the panel does not zoom out from an empty preview.
- The transient overflow pan now **animates back** when a drop settles; it
  used to snap back instantly.
- A staged drop no longer waits for the state settle. Staging changes nothing
  live, so the bindings reapply the staged position immediately and the fit
  updates at once. Only Apply holds the preview, because only Apply changes
  the live state.
- Pending entries are pruned when their display disappears (unplugged,
  disabled or mirrored), so a staged position cannot be applied to a screen
  that is gone.
- The state poll is 3 s instead of 5 s.

## 0.3.8

Zoom, and exact proportions.

- **Wheel over the preview to zoom**, about the pointer. The `−` / `+` chips
  zoom about the centre. **Fit** resets zoom and pan.
- One `scale` now drives the transform, the rectangle sizes and the snap
  limits. Previously the drawn rectangles had a 16x12 px floor, so at small
  scales the visual edges no longer matched the logical positions the snap
  and guides used. That was the inaccurate snapping and wrong-looking
  proportions.
- Zoom is clamped to 0.25x .. 6x.

## 0.3.7

Staged edits and a draggable preview.

- **Drops are staged, not applied.** A drag records the target position in a
  pending overlay; the live monitors are untouched until **Apply**. Multiple
  displays can be staged before applying. **Cancel** discards them all.
- The pending overlay feeds the geometry, the snap candidates and the
  validity check, so the preview and the invalid-layout strip describe what
  Apply would do, not the old arrangement.
- Apply holds the preview in place until the compositor reports the new
  positions, then drops the staged copy, so there is no frame where the
  preview falls back to the old state.
- **Drag the empty part of the preview to pan it**; **Fit** resets the pan.
  The automatic overflow pan remains separate and resets on drop.
- The Apply label becomes **Apply anyway** when the staged layout is invalid.

## 0.3.6

Overflow: a drag is no longer stopped by the edge of the preview.

The preview was clamped to its own bounds, so a display could not reach a
snap position that lay outside the fitted view. The bottom placements were
the visible casualty: the display hit the bottom of the preview before it
could reach the bottom edge or the bottom corners of another display.

When a dragged display reaches an edge, the view now pans by the amount the
display would have overflowed, and the display stays at the edge while its
world position keeps following the pointer. The pan is reset and the view
refitted when the drag settles. The preview is clipped so the panned
arrangement cannot draw over the rest of the panel.

Verified in the running shell with the in-page hook: dragging to the bottom
placement panned by 12 px and dropped at the exact bottom edge; dragging to
the bottom-right corner panned by 12 px and dropped at exactly
`(-5199, 255)` with `corner · flush right → DP-1 · flush below → DP-1` and
both guides.

## 0.3.5

The real cause of the display jumping to the top-left when a drag started.

The x and y of each monitor were held by a `Binding` that is switched off while
dragging. `Binding` defaults to restoring the value the property had before
the binding was applied, which is 0. So the moment `dragging` became true, x
and y snapped to 0,0, and the pointer delta was then applied from there. The
snap and the guides were correct; the item they were computed for was in the
wrong place.

`restoreMode: Binding.RestoreNone` keeps the current position when the binding
is disabled. Verified with a real synthetic drag injected through Hyprland's
Lua API: the press logged the item at (149,29), and the first movement logged
(149,29) rather than (0,0); the preview followed the pointer and the status
updated.

## 0.3.4

The drag was being destroyed by the state poll.

The monitor state replaces its array on every poll, even when nothing moved.
That array was fed straight into the Repeater, so every five seconds, and
after every action, every delegate was destroyed and recreated. Mid-drag this
removed the item under the pointer and recreated the monitors at 0,0, while
the guides stayed at their old coordinates. That is the "moving around the
viewport" behaviour.

The canvas now keeps a snapshot of the arrangement. It is compared by value
and only replaced when something actually changed, and it is never replaced
while a drag is running; a deferred sync is applied when the drag settles.

Verified in the running shell by starting a simulated drag and forcing a
state refresh mid-drag: the same delegate survived, `dragging` stayed true,
and the guides and status were unchanged.

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
