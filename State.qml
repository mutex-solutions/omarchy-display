import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    // Resolutions the kernel has but Hyprland was never given (a partial EDID
    // at connect, see kernelModes). sysfs carries no rates, so these are
    // offered at 60 Hz, the rate every EDID resolution is in practice listed
    // at; Hyprland builds the mode itself and falls back if the link refuses.
    var km = kernelModes[name] || []
    for (var j = 0; j < km.length; j++) {
      var kk = km[j].w + "x" + km[j].h
      if (!map[kk]) map[kk] = { w: km[j].w, h: km[j].h, maxRate: 60, mode: kk + "@60" }
    }
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
          s.noticeChange(out)
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
  // reload, so what the page applies is saved and turned into rules that
  // monitors.lua sources (see README, "Saved settings"):
  //
  //   ~/.config/deck/monitors.json  the record, read back on start so monitors
  //                                 that are not plugged in keep their entry
  //   ~/.config/deck/monitors.lua   generated from it: data only, handed to
  //                                 hypr/monitors.lua in this plugin
  //
  // Mode and scale are saved per monitor IDENTITY, positions per SET of
  // monitors. Disabled and mirrored outputs are not saved: a laptop panel shut
  // off by clamshell, or a screen turned off once, must not come back off.
  //
  // This plugin never edits ~/.config/hypr/monitors.lua itself.

  readonly property string deckDir: Quickshell.env("HOME") + "/.config/deck"
  readonly property string layoutPath: deckDir + "/monitors.lua"
  readonly property string storePath: deckDir + "/monitors.json"
  readonly property string applierPath: String(Qt.resolvedUrl("hypr/monitors.lua")).replace("file://", "")

  property bool pendingPersist: false
  property bool storeLoaded: false
  property var store: ({ monitors: {}, layouts: {} })

  // The description (make, model, serial) follows a monitor from port to port;
  // the connector name does not. Two enabled monitors reporting the same
  // description cannot be told apart by it, so both fall back to the connector.
  // Same rule as hypr/monitors.lua and Omarchy's monitor-workspaces.lua.
  function identityOf(m) {
    var d = String(m.description || "")
    if (d === "") return m.name
    var same = 0
    for (var i = 0; i < layoutMonitors.length; i++)
      if (layoutMonitors[i].description === d) same++
    return same === 1 ? d : m.name
  }

  function outputFor(m) {
    var id = identityOf(m)
    return id === m.name ? m.name : "desc:" + id
  }

  // Exact rate, so a 59.95 Hz choice is not saved as 60.
  function savedMode(m) {
    return m.w + "x" + m.h + "@" + (Math.round(Number(m.rate) * 1000) / 1000)
  }

  function luaString(v) {
    return '"' + String(v).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
      .replace(/\n/g, "\\n").replace(/\r/g, "\\r") + '"'
  }

  function layoutScript(st) {
    var L = ["-- Written by mutex-solutions.display from monitors.json. Do not edit by",
             "-- hand: the plugin rewrites it. The logic is in the plugin's hypr/monitors.lua.",
             "local data = {", "  monitors = {"]
    for (var id in st.monitors) {
      var e = st.monitors[id]
      L.push("    [" + luaString(id) + "] = { output = " + luaString(e.output)
        + ", mode = " + luaString(e.mode) + ", scale = " + Number(e.scale) + " },")
    }
    L.push("  },", "  layouts = {")
    for (var key in st.layouts) {
      var pos = st.layouts[key]
      var parts = []
      for (var pid in pos) parts.push("[" + luaString(pid) + "] = " + luaString(pos[pid]))
      L.push("    { " + parts.join(", ") + " },")
    }
    L.push("  },", "}",
           "local applier = " + luaString(applierPath),
           "local f = io.open(applier)",
           "if f then f:close(); dofile(applier)(data) end")
    return L.join("\n") + "\n"
  }

  function persistLayout() {
    if (!pendingPersist) return
    // Never write before the record is read, or every unplugged monitor's
    // entry would be lost.
    if (!storeLoaded) { persistTimer.restart(); return }
    // An automatic save that a plug or unplug overtook is dropped: what is on
    // screen now is a fallback, not a choice. The page's own actions still save.
    if (autoPersist && Date.now() - setChangedAt < settleMs) {
      pendingPersist = false
      autoPersist = false
      return
    }
    pendingPersist = false
    autoPersist = false

    var st = JSON.parse(JSON.stringify(store))
    if (!st.monitors) st.monitors = {}
    if (!st.layouts) st.layouts = {}
    var ids = []
    var layout = {}
    for (var i = 0; i < layoutMonitors.length; i++) {
      var m = layoutMonitors[i]
      if (!m.name || m.w <= 0 || m.h <= 0) continue
      var id = identityOf(m)
      st.monitors[id] = { output: outputFor(m), mode: savedMode(m), scale: m.scale,
                          lastConnector: m.name }
      layout[id] = m.x + "x" + m.y
      ids.push(id)
    }
    if (ids.length === 0) return
    ids.sort()
    st.layouts[ids.join("\n")] = layout

    store = st
    storeFile.setText(JSON.stringify(st, null, 2) + "\n")
    layoutFile.setText(layoutScript(st))
  }

  // Empty until prepareFiles has made sure the files exist: setText() needs
  // the directory and the file, and an empty file then reads as an empty
  // record instead of a load failure that would have to be told apart from a
  // permissions error.
  FileView {
    id: storeFile
    path: ""
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var t = String(text() || "").trim()
        var parsed = t === "" ? {} : JSON.parse(t)
        s.store = { monitors: parsed.monitors || {}, layouts: parsed.layouts || {} }
        s.storeLoaded = true
      } catch (e) {
        // A record that does not parse is left alone rather than overwritten.
        console.warn("display: " + s.storePath + " does not parse; not saving: " + e)
      }
    }
    // The file exists by now, so a failure is not "first run" and the record
    // is not replaced.
    onLoadFailed: console.warn("display: cannot read " + s.storePath + "; not saving")
  }

  Process {
    id: prepareFiles
    // Create only what is missing: `touch` on an existing file moves its mtime,
    // and every new bar (Omarchy builds one per screen, so a replug makes a new
    // one) would then look like a save.
    command: ["sh", "-c", 'mkdir -p "$1" && for f in "$2" "$3"; do [ -e "$f" ] || : > "$f"; done',
              "_", s.deckDir, s.layoutPath, s.storePath]
    onExited: function(code) {
      if (code === 0) storeFile.path = s.storePath
    }
  }

  FileView {
    id: layoutFile
    path: s.layoutPath
    atomicWrites: true
    printErrors: false
  }

  // Save changes made by ANY tool, not only this page: Omarchy's own display
  // panel, its scale keys, a hand-typed `hyprctl eval`. Left unsaved, the next
  // replug, re-detect or reload put back the older saved values over them
  // (found 2026-11-08: scales set from Omarchy's panel were reset by a
  // re-detect).
  //
  // But not every change is a choice. Right after a monitor is plugged in or
  // removed, what Hyprland shows is whatever it fell back to (a 1440p mode from a
  // short list), and saving that would overwrite the real choice. So a change
  // counts only while the same set of monitors has been there for settleMs.
  readonly property int settleMs: 8000
  property string lastSetKey: ""
  property string lastShape: ""
  property double setChangedAt: 0

  function noticeChange(list) {
    var names = []
    var shape = []
    for (var i = 0; i < list.length; i++) {
      var m = list[i]
      if (m.disabled || m.mirrorOf !== "none") continue
      names.push(m.name)
      shape.push(m.name + "=" + m.w + "x" + m.h + "@" + Math.round(m.rate * 1000)
        + "/" + m.scale + "/" + m.x + "x" + m.y)
    }
    names.sort()
    shape.sort()
    var setKey = names.join(",")
    var shapeKey = shape.join(";")
    var now = Date.now()
    if (setKey !== lastSetKey) {
      lastSetKey = setKey
      setChangedAt = now
    } else if (shapeKey !== lastShape && lastShape !== ""
               && now - setChangedAt >= settleMs && redetecting === "") {
      pendingPersist = true
      autoPersist = true
      persistTimer.restart()
    }
    lastShape = shapeKey
  }

  // The poll runs every 3 s, and a re-detect or a dock blip disconnects a
  // monitor for less than that, so the poll can miss the removal entirely and
  // read the half-restored layout after it as a choice (seen 2026-11-08: a save
  // landed mid re-detect). Hyprland's own events cannot be missed.
  property bool autoPersist: false

  function monitorsChanging() {
    setChangedAt = Date.now()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event ? String(event.name) : ""
      if (n.indexOf("monitoradded") === 0 || n.indexOf("monitorremoved") === 0)
        s.monitorsChanging()
    }
  }

  // ------------------------------------------------------------ kernel modes
  //
  // Hyprland reads a monitor's modes once, at connect. A dock that hands over a
  // partial EDID first leaves it with a short list (the XG27UCG offered 1440p
  // through an OWC Thunderbolt 3 dock while the kernel later had 4K), and a
  // config reload does not re-read it. The kernel's list is world-readable in
  // sysfs, so the resolution picker offers what the kernel has too. Read only:
  // forcing a re-probe needs root and is not this plugin's business.
  property var kernelModes: ({})

  Process {
    id: kernelModesProbe
    command: ["sh", "-c",
      'for c in /sys/class/drm/card*-*; do [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue; '
      + 'n=${c##*/}; n=${n#card*-}; sort -u "$c/modes" 2>/dev/null | sed "s/^/$n /"; done']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].match(/^(\S+) ([0-9]+)x([0-9]+)/)
          if (!p) continue
          if (!out[p[1]]) out[p[1]] = []
          out[p[1]].push({ w: Number(p[2]), h: Number(p[3]) })
        }
        s.kernelModes = out
      }
    }
  }

  Timer {
    id: persistTimer
    interval: 900
    onTriggered: s.persistLayout()
  }

  // ------------------------------------------------------------- re-detect
  //
  // A software unplug and replug of one external monitor, so Hyprland reads its
  // modes afresh (see kernelModes). It needs root, so it goes through pkexec and
  // the polkit agent prompts. The helper and its polkit action are installed
  // once by scripts/install-redetect.sh; until then the button is hidden. The
  // saved settings bring the monitor back as it was, through monitor.added.
  readonly property string redetectHelper: "/usr/local/libexec/omarchy-display-redetect"
  property bool redetectAvailable: false
  property string redetecting: ""
  property string redetectError: ""

  Process {
    id: redetectProbe
    command: ["sh", "-c", 'test -x "$1" && test -f /usr/share/polkit-1/actions/com.mutex-solutions.display.redetect.policy',
              "_", s.redetectHelper]
    onExited: function(code) { s.redetectAvailable = (code === 0) }
  }

  Process {
    id: redetectRunner
    command: ["true"]
    stderr: StdioCollector { id: redetectStderr; waitForEnd: true }
    onExited: function(code) {
      // 126: the prompt was dismissed; 127: not authorised. Neither is an error
      // worth a red line, the user chose it.
      if (code === 0 || code === 126) s.redetectError = ""
      else if (code === 127) s.redetectError = "Not authorised to re-detect"
      else s.redetectError = (String(redetectStderr.text || "").trim()
                              || ("Re-detect failed (" + code + ")"))
      s.redetecting = ""
      s.monitorsChanging()
      settleTimer.restart()
    }
  }

  function canRedetect(m) {
    return redetectAvailable && !!m && !m.disabled && !isInternal(m.name)
  }

  function redetect(name) {
    if (redetectRunner.running || !name || isInternal(name)) return
    redetectError = ""
    redetecting = name
    monitorsChanging()
    redetectRunner.command = ["pkexec", redetectHelper, name]
    redetectRunner.running = true
  }

  // ---------------------------------------------------------------- polling

  function refresh() {
    if (!monitorProbe.running) monitorProbe.running = true
    if (!kernelModesProbe.running) kernelModesProbe.running = true
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
    prepareFiles.running = true
    redetectProbe.running = true
    refresh()
  }
}
