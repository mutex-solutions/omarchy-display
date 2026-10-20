# Display

Monitors, their arrangement, and brightness, for Omarchy. A bar widget, or a
section inside [Deck](https://github.com/mutex-solutions/omarchy-deck).

## Standalone

```bash
omarchy plugin add https://github.com/mutex-solutions/omarchy-display --enable
```

Click the sun icon to open the panel.

## Inside Deck

```bash
omarchy plugin add https://github.com/mutex-solutions/omarchy-display
```

```json
{ "id": "display", "title": "Display",
  "file": "/home/YOU/.config/omarchy/plugins/mutex-solutions.display/deck/Section.qml",
  "page": "/home/YOU/.config/omarchy/plugins/mutex-solutions.display/deck/Page.qml" }
```

`install-bundle.sh` in the Deck repo does this for every section at once.

## What the page does

- **Layout** draws every enabled monitor to scale, placed the way Hyprland has
  them. **Drag any display freely**; the drop is staged, not applied. A
  pending edit is shown in the preview and nothing happens to the live
  arrangement until **Apply** is pressed. **Cancel** discards every staged
  edit, and **Fit** recentres a panned preview.
- **Drag the empty part of the preview to pan it.** A display dragged past an
  edge pans the view automatically, so snap positions outside the fitted view
  are still reachable.
- **Snapping** uses complete placements relative to the other displays, so a
  snap always produces a placement that touches:
  - edge to edge: within **12 screen px**
  - corner to corner: within **8 px**, including the diagonal where two
    corners meet
  - centre line: within **5 px**
  A held snap survives a brief excursion past those distances (1.5× for
  **160 ms**), so a shaky hand does not knock it loose. A quick shake never
  releases; a deliberate drag away does.
- **Guides** draw at the matched edge or centre line, with a marker where the
  two lines cross. The status row names the pair and shows the exact
  coordinates.
- **Invalid layout**: every display must share an edge or corner with another
  display, and an overlap is invalid too. The drop still applies (Hyprland
  accepts gaps and overlaps), but a red strip says what is wrong, and the
  offending display is outlined while it is dragged.
- **Displays** lists every output with its mode and refresh rate. Pick one to
  arrange; the switch turns an output on or off.
- **Mirror** shows the target on the first other enabled monitor.
- **Windows** moves windows between screens. **Move** sends the focused window
  to the other monitor (a window belongs to a workspace, and a workspace
  belongs to a monitor, so the move goes to the workspace that screen is
  showing). **Swap screens** swaps the two monitors' active workspaces, which
  moves every window on each screen to the other one in a single step and is
  its own undo.
- **Brightness** uses `brightnessctl`; it appears only when the machine has a
  backlight to control.

Positions are in **scaled logical pixels**: a 3840×2160 panel at scale 2
occupies 1920×1080 in the layout, which is exactly what Hyprland expects.
The preview fits the arrangement with half a display of room on each side.
The panel is narrow, so that is the balance between drag room and a preview
that can still be aimed; there is no zoom control.

Hyprland has no "primary output" in the X11 sense: there is no flag to mark
one monitor as primary. What decides where new windows appear is the workspace
a window opens on, and workspaces are bound to monitors by the layout order in
your config. **Swap screens** is therefore the practical primary/secondary
control: it exchanges what each screen is showing without touching the
arrangement.

## Arrangement and config reloads

Hyprland applies an `hl.monitor` rule to the running compositor, but it does not
remember it: the next config reload re-applies whatever `monitors.lua` says.
To make an arrangement stick, add one line to `~/.config/hypr/monitors.lua`
after your own rules:

```lua
dofile((os.getenv("HOME") or "") .. "/.config/deck/monitors.lua")
```

The plugin writes that file (`~/.config/deck/monitors.lua`) every time you move,
mirror or disable an output. It never edits `monitors.lua` itself.

## How it is built

| File | Role |
| --- | --- |
| `State.qml` | monitors and brightness over `hyprctl` and `brightnessctl` |
| `deck/Section.qml` | the members Deck reads |
| `deck/Page.qml` | the panel content |
| `Panel.qml` | the standalone bar widget and its popup |

Nothing is written optimistically: every action runs one `hyprctl eval`, waits
for the compositor to settle, then re-reads `hyprctl monitors all -j`, so what
the panel shows is what the compositor reports. A rule Hyprland refuses shows
up as "nothing moved" rather than as a button that appears to have worked.

## Requirements

Omarchy 4.x, Hyprland, `brightnessctl`.

## Licence

MIT. See [LICENSE](LICENSE).
