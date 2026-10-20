import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Display state: every monitor, its layout position, brightness, and the
// actions that rearrange them.
//
// Hyprland positions are in SCALED logical pixels, so a 3840x2160 panel at
// scale 2 occupies 1920x1080 in the layout. Every calculation here uses
// logical size; the physical size is only ever displayed.
Item {
  id: s

  // [{ name, description, w, h, x, y, scale, rate, disabled, mirrorOf, focused }]
  // New fields are appended by the code that reads them; the preview only
  // ever needs the ones above.
  property var monitors: []

  property int brightness: 0
  property bool brightnessAvailable: true

  readonly property bool active: true
  readonly property string label: "Display"
  readonly property string icon: "☼"

  readonly property var enabledMonitors: {
    var out = []
    for (var i = 0; i < monitors.length; i++)
      if (!monitors[i].disabled) out.push(monitors[i])
    return out
  }

  // Mirrored outputs are enabled but sit on top of another monitor, so they
  // are not part of the extended desktop and must not be drawn in the layout
  // preview (they would overlap their target exactly).
  readonly property var layoutMonitors: {
    var out = []
    for (var i = 0; i < monitors.length; i++)
      if (!monitors[i].disabled && monitors[i].mirrorOf === "none") out.push(monitors[i])
    return out
  }

  readonly property var focusedMonitor: {
    for (var i = 0; i < monitors.length; i++)
      if (monitors[i].focused) return monitors[i]
    return enabledMonitors.length ? enabledMonitors[0] : null
  }

  readonly property string detail: {
    if (!focusedMonitor) return ""
    var parts = []
    if (enabledMonitors.length > 1) parts.push(enabledMonitors.length + " displays")
    parts.push(Math.round(focusedMonitor.rate) + " Hz")
    return parts.join(" · ")
  }

  function byName(name) {
    for (var i = 0; i < monitors.length; i++)
      if (monitors[i].name === name) return monitors[i]
    return null
  }

  function logicalW(m) { return m && m.scale > 0 ? Math.round(m.w / m.scale) : 0 }
  function logicalH(m) { return m && m.scale > 0 ? Math.round(m.h / m.scale) : 0 }

  function modeString(m) {
    return m.w + "x" + m.h + "@" + Math.round(m.rate)
  }

  // ---------------------------------------------------------------- actions

  // Every action is one hyprctl eval. Fire and forget: state is re-read after
  // a settle delay, never assumed, so a refused rule shows up as "nothing
  // moved" rather than as a lie.
  function applyLua(script) {
    Quickshell.execDetached(["hyprctl", "eval", script])
    pendingPersist = true
    settleTimer.restart()
  }

  // Explicit position, in logical pixels. `mirror = ""` makes arranging an
  // output always mean "extended": without it a rule can leave an output
  // mirrored while its position says otherwise.
  function moveTo(name, x, y) {
    var m = byName(name)
    if (!m) return
    applyLua('hl.monitor({ output = "' + name + '", mode = "' + modeString(m)
      + '", position = "' + Math.round(x) + "x" + Math.round(y)
      + '", scale = ' + m.scale + ', mirror = "" })')
  }

  // Predefined position relative to the other monitors: left, right, up,
  // down. Hyprland computes it, so it stays correct with three or more
  // screens and never relies on a guessed pixel offset.
  function placeRelative(name, direction) {
    var m = byName(name)
    if (!m) return
    applyLua('hl.monitor({ output = "' + name + '", mode = "' + modeString(m)
      + '", position = "auto-' + direction + '", scale = ' + m.scale
      + ', mirror = "" })')
  }

  function mirrorTo(name, target) {
    applyLua('hl.monitor({ output = "' + name + '", mirror = "' + target + '" })')
  }

  function unmirror(name) {
    var m = byName(name)
    if (!m) return
    applyLua('hl.monitor({ output = "' + name + '", mirror = "", mode = "'
      + modeString(m) + '", position = "auto-right", scale = ' + m.scale + ' })')
  }

  function setDisabled(name, off) {
    var m = byName(name)
    if (off) {
      applyLua('hl.monitor({ output = "' + name + '", disabled = true })')
      return
    }
    // A disabled output has no usable mode, so bring it back explicitly
    // rather than trusting whatever Hyprland remembers.
    applyLua('hl.monitor({ output = "' + name + '", disabled = false, mode = "preferred"'
      + ', position = "auto-right", scale = ' + (m && m.scale > 0 ? m.scale : 1)
      + ', mirror = "" })')
  }

  // ---------------------------------------------------------------- reading

  Process {
    id: monitorProbe
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var raw = JSON.parse(text || "[]")
          var out = []
          for (var i = 0; i < raw.length; i++) {
            var m = raw[i]
            out.push({
              id: Number(m.id || 0),
              name: String(m.name || ""),
              description: String(m.description || ""),
              w: Number(m.width || 0),
              h: Number(m.height || 0),
              x: Number(m.x || 0),
              y: Number(m.y || 0),
              scale: Number(m.scale || 1),
              rate: Number(m.refreshRate || 0),
              disabled: m.disabled === true,
              // Hyprland reports the mirror target as a monitor *id*, not a
              // name ("none" when not mirrored). Resolve it below, once every
              // monitor is known.
              mirrorId: Number(m.mirrorOf || 0),
              mirrorOf: "none",
              focused: m.focused === true
            })
          }
          for (var j = 0; j < out.length; j++) {
            if (out[j].mirrorId <= 0) continue
            for (var k = 0; k < out.length; k++) {
              if (out[k].id === out[j].mirrorId) {
                out[j].mirrorOf = out[k].name
                break
              }
            }
          }
          s.monitors = out
        } catch (e) {
        }
      }
    }
  }

  Process {
    id: brightnessProbe
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") { s.brightnessAvailable = false; return }
        var parts = raw.split(",")
        if (parts.length < 5) { s.brightnessAvailable = false; return }
        var pct = parseInt(String(parts[3]).replace("%", ""), 10)
        if (!isNaN(pct)) { s.brightnessAvailable = true; s.brightness = pct }
      }
    }
  }

  Process {
    id: brightnessSetter
    command: ["true"]
  }

  function setBrightness(pct) {
    var value = Math.max(1, Math.min(100, Math.round(Number(pct))))
    s.brightness = value
    brightnessSetter.command = ["brightnessctl", "set", value + "%"]
    if (!brightnessSetter.running) brightnessSetter.running = true
  }

  // ------------------------------------------------------------ persistence
  //
  // Hyprland does not remember a live `hl.monitor` rule across a config
  // reload, so the arrangement is written to a small Lua file after every
  // change. Sourcing it from monitors.lua makes the arrangement survive:
  //
  //   dofile(os.getenv("HOME") .. "/.config/deck/monitors.lua")
  //
  // This plugin never edits monitors.lua itself.

  readonly property string layoutPath: Quickshell.env("HOME") + "/.config/deck/monitors.lua"

  property bool pendingPersist: false

  function layoutScript() {
    var lines = ["-- Written by mutex-solutions.display. Do not edit by hand."]
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i]
      if (!m.name) continue
      if (m.disabled) {
        lines.push('hl.monitor({ output = "' + m.name + '", disabled = true })')
      } else if (m.mirrorOf && m.mirrorOf !== "none") {
        lines.push('hl.monitor({ output = "' + m.name + '", mirror = "' + m.mirrorOf + '" })')
      } else {
        lines.push('hl.monitor({ output = "' + m.name + '", mode = "' + modeString(m)
          + '", position = "' + m.x + "x" + m.y + '", scale = ' + m.scale + ' })')
      }
    }
    return lines.join("\n") + "\n"
  }

  function persistLayout() {
    if (!pendingPersist) return
    pendingPersist = false
    layoutFile.setText(layoutScript())
  }

  FileView {
    id: layoutFile
    path: s.layoutPath
    atomicWrites: true
    printErrors: false
  }

  Timer {
    id: persistTimer
    interval: 900
    onTriggered: s.persistLayout()
  }

  // ---------------------------------------------------------------- polling

  function refresh() {
    if (!monitorProbe.running) monitorProbe.running = true
    if (!brightnessProbe.running) brightnessProbe.running = true
  }

  // After an action, wait for the compositor to settle, re-read, then write
  // the arrangement from what was actually applied.
  Timer {
    id: settleTimer
    interval: 700
    onTriggered: {
      s.refresh()
      persistTimer.restart()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: s.refresh()
  }

  Component.onCompleted: {
    // setText() needs both the directory and the file to exist.
    Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && touch "$2"', "_",
      Quickshell.env("HOME") + "/.config/deck", layoutPath])
    refresh()
  }
}
