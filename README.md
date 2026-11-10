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
- **Zoom with the wheel over the preview**, or with the `−` / `+` chips. The
  wheel zooms about the pointer; the chips zoom about the centre. **Fit**
  resets both zoom and pan. One scale drives the transform, the drawn
  rectangles and the snap distances, so the guides and the screen edges agree
  at every zoom.
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
  arrange; the switch turns an output on or off. **Refresh rate** selects from
  the modes the panel actually advertises at its current resolution, read from
  `hyprctl`'s `availableModes`. The mode in use is included even when the panel
  does not advertise it (the XPS 13 accepts a custom 60 Hz mode that is absent
  from the list). The internal panel also gets its native 60 Hz mode even
  though it is absent from `availableModes`, which is what makes the 120/60
  choice possible on the XPS 13. A rate change **applies immediately**: it is
  an explicit selection and trivially reversible. Positions remain staged
  behind Apply/Cancel, because those are the ones that are easy to knock.
- **Brightness follows the selected display** through
  `omarchy-brightness-display`, which handles the internal backlight, Apple
  displays and DDC/CI for external ones. The ASUS reports and accepts DDC
  brightness, so the section is real for both screens; it is hidden when the
  helper reports no controllable backlight.
- **Resolution** is chosen from the modes the panel advertises, labelled by
  common aspect ratio (16:9, 16:10, 3:2, 21:9, 4:3, 5:4). Picking one applies
  its highest rate immediately. Resolutions the kernel has but Hyprland was
  never given are offered too, at 60 Hz (see [Saved settings](#saved-settings)).
- **Scale** uses the same cleaned presets as `omarchy-hyprland-monitor-scaling`
  (1, 1.25, 1.6, 2, 3, 4, rounded to a scale Hyprland accepts for the mode).
- **Text size** drives `omarchy-display-text-size`, so the shell, GTK apps and
  terminals move together, as in the stock display panel.
- **Sections collapse** from their headers; the chevron shows the state. On a
  single monitor the layout canvas collapses away while resolution, rate, scale,
  brightness and text size remain available. The last enabled output cannot be
  switched off from the page.
- **Mirror** shows the target on the first other enabled monitor.
- **Window and workspace moves live in Sessions**, not here. Display owns the
  physical arrangement and per-monitor settings.

Positions are in **scaled logical pixels**: a 3840×2160 panel at scale 2
occupies 1920×1080 in the layout, which is exactly what Hyprland expects.
The preview fits the arrangement with half a display of room on each side.
Zoom and pan keep that initial fit usable when a drag needs to reach beyond it.

Hyprland has no "primary output" in the X11 sense: there is no flag to mark
one monitor as primary. What decides where new windows appear is the workspace
a window opens on, and workspaces are bound to monitors by the layout order in
your config. **Swap sessions** in the Sessions section is therefore the practical
primary/secondary control: it exchanges what each screen is showing without
touching the physical arrangement.

## Saved settings

Hyprland applies an `hl.monitor` rule to the running compositor, but it does not
remember it: the next config reload re-applies whatever `monitors.lua` says.
To make the page's changes stick, add this to the **end** of
`~/.config/hypr/monitors.lua`, after your own rules:

```lua
local deck = (os.getenv("HOME") or "") .. "/.config/deck/monitors.lua"
local deck_file = io.open(deck)
if deck_file then deck_file:close(); dofile(deck) end
```

It goes last so its rules win over a catch-all `output = ""` rule. The plugin
never edits `monitors.lua` itself.

What is saved: every change to a mode, scale or position, whichever tool made it
(this page, Omarchy's display panel or scale keys, `hyprctl`). A change seen within
8 s of a monitor being plugged in or removed is not saved, because that is
Hyprland's fallback rather than a choice:

| Setting | Saved per | Why |
| --- | --- | --- |
| Resolution + refresh rate, scale | **monitor**, by its EDID description (make, model, serial) | the description follows a monitor to any port or dock; `DP-3` today can be `DP-1` tomorrow. Two connected monitors with the same description fall back to their connector names |
| Position | **set of monitors** in use | a position only means something next to the screens it was arranged against. The laptop alone at `0x0` and the monitor docked at `0x0` are both right, but together they overlap, so a saved layout applies only when exactly the same monitors are enabled again. Any other combination gets Hyprland's `auto` placement |
| Brightness | not saved here | the system already keeps it: `systemd-backlight` restores the laptop panel at boot, and an external monitor stores its own DDC/CI brightness |

Disabled and mirrored outputs are not saved. The laptop panel switched off by
clamshell, or a screen turned off once, must not come back switched off the next
time it is plugged in.

The record is `~/.config/deck/monitors.json`. It keeps monitors that are not
plugged in, so a monitor's settings wait for it. From it the plugin generates
`~/.config/deck/monitors.lua`, which holds only data and calls
[`hypr/monitors.lua`](hypr/monitors.lua) in this plugin. That file makes the
per-monitor rules and re-applies the matching layout on `monitor.added`/`removed`,
because a hotplug does not re-run the config. It also reconciles the session-wide
`GDK_SCALE` from the lowest rounded active-monitor scale, matching Omarchy's
XWayland/GTK behavior without invoking a second config writer. If the plugin is
removed, the generated file quietly does nothing.

### Why the mode is saved explicitly, not as "preferred"

Hyprland reads a monitor's list of modes **once, when the connector connects**.
Through an OWC Thunderbolt 3 dock, an ASUS XG27UCG (4K, 160 Hz) handed over a
partial EDID first. Hyprland got a list that stopped at 2560×1440, and later the
kernel had the full 4K list. Hyprland never re-read it, and **a config reload
does not re-read it either** (tested). `"preferred"` then means "the best of the
short list". A saved `3840x2160@60` still works: Hyprland builds a custom mode
when the requested one is missing from its list, and if the link really cannot
carry it, it falls back to the preferred mode on its own. Unplugging and
replugging the cable is the only thing that refreshes the list.

The **Resolution** picker therefore also offers the resolutions in the kernel's
own list (`/sys/class/drm/card*-<output>/modes`, readable without root). sysfs
carries no refresh rates, so those are offered at 60 Hz.

### Re-detect

Each external monitor in **Displays** has a **Re-detect** button: a software
unplug and replug. It forces the connector off in the kernel, then hands it back
to `detect`. The monitor stays powered, so the kernel finds it again within a
second, reads its EDID afresh and reports a new connect, and Hyprland reads the
full mode list. The saved settings then bring it back as it was. The screen
blanks for about two seconds.

It needs root (`/sys/class/drm/*/status` is root-only), so it goes through
`pkexec` and the shell's polkit prompt. The policy allows exactly one program,
and asks again only after about five minutes (`auth_admin_keep`). Install the
root half once; the button is hidden until then:

```bash
bash ~/.config/omarchy/plugins/mutex-solutions.display/scripts/install-redetect.sh
# --remove to uninstall
```

| File | Installed to |
| --- | --- |
| `system/omarchy-display-redetect` | `/usr/local/libexec/` |
| `system/com.mutex-solutions.display.redetect.policy` | `/usr/share/polkit-1/actions/` |

The laptop panel never gets the button. The helper refuses `eDP`/`LVDS`/`DSI`,
connector names that are not plain, and a connector that is not connected.

What did **not** work, tested on the ASUS XG27UCG, so it is not tried again:

| Tried | Result |
| --- | --- |
| `hyprctl reload` | the mode list is not re-read |
| output off and on in Hyprland | the mode list is not re-read |
| DDC/CI standby, then wake (VCP `D6`) | the standby **is** a real disconnect, but DDC runs over the link that just dropped, so the wake is never delivered. The monitor needs its power button |
| forcing the connector `on` while the monitor sleeps | the kernel gets a 0-byte EDID and the output flaps |

## How it is built

| File | Role |
| --- | --- |
| `State.qml` | monitors and brightness over `hyprctl` and `brightnessctl`; writes the saved settings |
| `hypr/monitors.lua` | applies the saved settings inside Hyprland |
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
