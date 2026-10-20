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
  them. **Drag any display freely**: the drop is applied as an exact position,
  and it snaps to another screen's edges and centre lines when the pointer is
  within about 8 screen pixels of them, so both "anywhere" and "flush" are
  easy. A screen that overlaps another turns the urgent colour while it is
  dragged, because an overlap hides part of a display; Hyprland accepts it, so
  the drop still applies. A click without movement selects the screen.
- **Eight placement boxes** sit around the reference monitor: the four edges
  (centred) and the four corners, for exact presets. Click a box to put the
  selected monitor there. A box a monitor already occupies is not drawn,
  because that place is taken.
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
Edge boxes centre the target on that edge; corner boxes sit it diagonally
outside the corner. Hyprland's own `auto-*` positions only cover the edges and
align rather than centre, so the eight boxes are computed as explicit
positions from the sizes the compositor reports.

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
