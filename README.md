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
  them. Click a monitor to make it the target of the controls below.
- **Displays** lists every output with its mode and refresh rate. Pick one to
  arrange; the switch turns an output on or off.
- **Position** puts the target to the left of, right of, above or below the
  other monitors. These use Hyprland's own `auto-left` / `auto-right` /
  `auto-up` / `auto-down` positions, so the arrangement is computed from the
  real geometry rather than from a guessed pixel offset, and stays correct with
  three or more screens.
- **Mirror** shows the target on the first other enabled monitor.
- **Brightness** uses `brightnessctl`; it appears only when the machine has a
  backlight to control.

Positions are in **scaled logical pixels**: a 3840×2160 panel at scale 2
occupies 1920×1080 in the layout, which is exactly what Hyprland expects.

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
