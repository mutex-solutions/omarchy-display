# Display

Brightness and refresh rate for Omarchy. A bar widget, or a section inside
[Deck](https://github.com/mutex-solutions/omarchy-deck).

## Standalone

```bash
omarchy plugin add https://github.com/mutex-solutions/omarchy-display --enable
```

Click the sun icon: a brightness slider, and a refresh switch when the display
offers a second rate.

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

## How it is built

| File | Role |
| --- | --- |
| `State.qml` | brightness and monitor state over brightnessctl and hyprctl |
| `deck/Section.qml` | the five members Deck reads |
| `deck/Page.qml` | the panel content |
| `Panel.qml` | the standalone bar widget and its popup |

Brightness is read from `brightnessctl -m` and written with
`brightnessctl set`. Refresh is read from `hyprctl monitors -j` and switched
with Hyprland's own monitor command, so it survives a config reload.

The refresh control appears only when the display advertises a 60 Hz mode in
`availableModes`; on a single-rate panel the page says so instead of offering a
button that would do nothing.

## Requirements

Omarchy 4.x, `brightnessctl`, Hyprland.

## Licence

MIT. See [LICENSE](LICENSE).
