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
  property bool brightnessAvailable: false
  property string brightnessMonitor: ""
  property string brightnessProbeName: ""
  property string pendingBrightnessProbe: ""

  readonly property bool active: true
  readonly property string label: "Display"
  readonly property string icon: "󰍹"

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

  function currentMode(m) {
    return m ? modeString(m) : ""
  }

  // The internal panel is the one with a backlight. brightnessctl addresses
  // that panel only; an external display has no backlight here.
  function isInternal(name) {
    return /^(eDP|LVDS|DSI)/.test(String(name))
  }
  function hasBrightness(name) {
    return brightnessAvailable && isInternal(name)
  }

  function rateLabel(rate) {
    var r = Math.round(Number(rate) * 100) / 100
    return (Math.abs(r - Math.round(r)) < 0.005 ? String(Math.round(r)) : r.toFixed(2)) + " Hz"
  }

  function modeRateLabel(mode) {
    var p = String(mode).match(/@([0-9.]+)/)
    return p ? rateLabel(Number(p[1])) : ""
  }

  // Refresh rates the panel advertises at its CURRENT resolution. The mode in
  // use is included even when the panel does not advertise it (the XPS 13
  // accepts a custom 60 Hz mode that is absent from availableModes).
  function gcd(a, b) {
    while (b) { var t = a % b; a = b; b = t }
    return a
  }

  // Hyprland only accepts scales where the mode divides into whole logical
  // pixels (1/120 steps), the same rule as omarchy-hyprland-monitor-scaling.
  function cleanScale(scale, w, h) {
    var g = gcd(w * 120, h * 120)
    var k = Math.round(Number(scale) * 120)
    if (k > g) k = g
    while (g % k !== 0) k++
    return k / 120
  }

  function scaleLabel(scale) {
    var s = Math.round(Number(scale) * 100) / 100
    return (Math.abs(s - Math.round(s)) < 0.005 ? String(Math.round(s)) : s.toFixed(2)) + "×"
  }

  function scaleOptions(w, h) {
    var presets = [1, 1.25, 1.6, 2, 3, 4]
    var out = []
    var seen = {}
    for (var i = 0; i < presets.length; i++) {
      var c = cleanScale(presets[i], w, h)
      var key = String(Math.round(c * 10000))
      if (seen[key]) continue
      seen[key] = true
      out.push({ value: c, label: scaleLabel(c) })
    }
    return out
  }

  function aspectLabel(w, h) {
    var r = w / h
    var known = [[16 / 9, "16:9"], [16 / 10, "16:10"], [3 / 2, "3:2"],
                 [21 / 9, "21:9"], [32 / 9, "32:9"], [4 / 3, "4:3"], [5 / 4, "5:4"]]
    var best = null
    var bestD = 0.02
    for (var i = 0; i < known.length; i++) {
      var d = Math.abs(r - known[i][0])
      if (d < bestD) { bestD = d; best = known[i][1] }
    }
    return best
  }

  // Resolutions the panel advertises, grouped and labelled by common aspect
  // ratio. Small legacy modes are dropped; the current resolution is always
  // present even if it matches nothing. `mode` is the highest-rate mode at
  // that resolution, used when the user picks it.
  function resolutionsFor(name) {
    var m = byName(name)
    if (!m) return []
    var map = {}
    for (var i = 0; i < m.modes.length; i++) {
      var p = String(m.modes[i]).match(/^([0-9]+)x([0-9]+)@([0-9.]+)Hz$/)
      if (!p) continue
      var w = Number(p[1]), h = Number(p[2]), rate = Number(p[3])
      var key = w + "x" + h
      if (!map[key]) map[key] = { w: w, h: h, maxRate: 0, mode: "" }
      if (rate > map[key].maxRate) {
        map[key].maxRate = rate
        map[key].mode = w + "x" + h + "@" + p[3]
      }
    }
    var cur = m.w + "x" + m.h
    if (!map[cur]) map[cur] = { w: m.w, h: m.h, maxRate: Number(m.rate), mode: currentMode(m) }
    var out = []
    for (var k in map) {
      var e = map[k]
      var asp = aspectLabel(e.w, e.h)
      var isCurrent = e.w === m.w && e.h === m.h
      if (!isCurrent && (e.h < 720 || asp === null)) continue
      out.push({
        w: e.w, h: e.h, mode: e.mode, maxRate: e.maxRate, aspect: asp,
        label: e.w + "×" + e.h + (asp ? " · " + asp : "")
      })
    }
    out.sort(function(a, b) { return b.w * b.h - a.w * a.h })
    return out
  }

  function ratesFor(name, wantW, wantH) {
    var m = byName(name)
    if (!m) return []
    var out = []
    var seen = {}
    var tw = (wantW !== undefined && wantW > 0) ? wantW : m.w
    var th = (wantH !== undefined && wantH > 0) ? wantH : m.h
    var res = tw + "x" + th
    var isNative = (tw === m.w && th === m.h)
    for (var i = 0; i < m.modes.length; i++) {
      var ms = String(m.modes[i])
      var p = ms.match(/^([0-9]+)x([0-9]+)@([0-9.]+)Hz$/)
      if (!p) continue
      if (p[1] + "x" + p[2] !== res) continue
      var rate = Number(p[3])
      var key = rate.toFixed(2)
      if (seen[key]) continue
      seen[key] = true
      // hyprctl reports "WxH@RHz" but hl.monitor wants "WxH@R". Passing the
      // Hz form back is silently rejected.
      out.push({ mode: p[1] + "x" + p[2] + "@" + p[3], rate: rate,
                 label: rateLabel(rate) })
    }
    var ck = Number(m.rate).toFixed(2)
    if (isNative && !seen[ck]) {
      seen[ck] = true
      out.push({ mode: currentMode(m), rate: Number(m.rate), label: rateLabel(m.rate) })
    }
    // The XPS 13 panel advertises only 120 Hz but accepts its native
    // 2560x1600@60 mode. Without this fallback the 120/60 choice is invisible.
    // The seen check must include the current-mode entry above, or a live
    // 60 Hz rate would be listed twice.
    if (isNative && isInternal(m.name) && !seen["60.00"]) {
      seen["60.00"] = true
      out.push({ mode: res + "@60", rate: 60, label: rateLabel(60) })
    }
    out.sort(function(a, b) { return a.rate - b.rate })
    return out
  }

  // ---------------------------------------------------------------- actions

  // Every action is one hyprctl eval. Fire and forget: state is re-read after
  // a settle delay, never assumed, so a refused rule shows up as "nothing
  // moved" rather than as a lie.
  function applyLua(script, touchesLayout) {
    Quickshell.execDetached(["hyprctl", "eval", script])
    // Only monitor rules belong in the layout file. A window move or a
    // workspace swap does not change the arrangement, so it must not rewrite
    // it (and must not imply the arrangement changed).
    if (touchesLayout !== false) pendingPersist = true
    settleTimer.restart()
  }

  // Mode, position and scale in one rule. The mode is part of the rule so a
  // staged rate and a staged position are applied together, not in two steps
  // that can briefly disagree.
  function applyArrangement(name, x, y, mode, scale) {
    var m = byName(name)
    if (!m) return
    var md = (mode && String(mode) !== "") ? String(mode) : modeString(m)
    var sc = (scale !== undefined && Number(scale) > 0) ? Number(scale) : m.scale
    applyLua('hl.monitor({ output = "' + name + '", mode = "' + md
      + '", position = "' + Math.round(x) + "x" + Math.round(y)
      + '", scale = ' + sc + ', mirror = "" })')
  }

  // Apply a whole arrangement in one eval. Moving one output into another's
  // old area can make Hyprland shift the other; sending every output's final
  // position in one script leaves the requested layout in place. Staged
  // outputs must come first, the anchors after them.
  function applyLayout(entries) {
    if (!entries || entries.length === 0) return
    var lines = []
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      var m = byName(e.name)
      if (!m) continue
      var md = (e.mode && String(e.mode) !== "") ? String(e.mode) : modeString(m)
      var sc = (e.scale !== undefined && Number(e.scale) > 0) ? Number(e.scale) : m.scale
      lines.push('hl.monitor({ output = "' + e.name + '", mode = "' + md
        + '", position = "' + Math.round(e.x) + "x" + Math.round(e.y)
        + '", scale = ' + sc + ', mirror = "" })')
    }
    if (lines.length) applyLua(lines.join("\n"))
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
              modes: (m.availableModes && m.availableModes.length)
                ? m.availableModes.slice() : [],
              activeWorkspaceId: Number((m.activeWorkspace && m.activeWorkspace.id) || 0),
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
    command: ["true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (s.brightnessProbeName !== s.brightnessMonitor) return
        var raw = String(text || "").trim()
        var pct = parseInt(raw, 10)
        if (raw === "" || raw === "unavailable" || isNaN(pct)) {
          s.brightnessAvailable = false
          s.brightness = 0
        } else {
          s.brightnessAvailable = true
          s.brightness = Math.max(0, Math.min(100, pct))
        }
      }
    }
    onExited: {
      if (s.pendingBrightnessProbe !== "" && s.pendingBrightnessProbe !== s.brightnessProbeName) {
        var next = s.pendingBrightnessProbe
        s.pendingBrightnessProbe = ""
        s.startBrightnessProbe(next)
      }
    }
  }

  function startBrightnessProbe(name) {
    s.brightnessMonitor = name
    s.brightnessProbeName = name
    s.brightnessAvailable = false
    brightnessProbe.command = ["omarchy-brightness-display", "--monitor", name]
    brightnessProbe.running = true
  }

  function probeBrightness(name) {
    if (!name) {
      s.brightnessMonitor = ""
      s.brightnessAvailable = false
      return
    }
    if (brightnessProbe.running) {
      s.pendingBrightnessProbe = name
      return
    }
    s.startBrightnessProbe(name)
  }

  Process {
    id: brightnessSetter
    command: ["true"]
  }

  function setBrightness(pct) {
    var value = Math.max(1, Math.min(100, Math.round(Number(pct))))
    s.brightness = value
    if (s.brightnessMonitor === "") return
    brightnessSetter.command = ["omarchy-brightness-display", "--no-osd",
      "--monitor", s.brightnessMonitor, value + "%"]
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
    interval: 3000
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
