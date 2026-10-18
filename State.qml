import QtQuick
import Quickshell
import Quickshell.Io

// Display state: brightness and refresh rate.
//
// Brightness goes through brightnessctl, which every Omarchy laptop has.
// Refresh is read from hyprctl and switched through Hyprland's own monitor
// command, then persisted so a reload re-applies it.
Item {
  id: s

  readonly property bool active: true
  readonly property string label: "Display"
  readonly property string icon: "☼"

  property int brightness: 0
  property bool brightnessAvailable: true

  property string monitorName: ""
  property int monitorWidth: 0
  property int monitorHeight: 0
  property real monitorRefresh: 0
  property real monitorScale: 1
  property bool supports60: false

  readonly property string detail: {
    var parts = []
    if (brightnessAvailable) parts.push(brightness + "%")
    if (monitorRefresh > 0) parts.push(Math.round(monitorRefresh) + " Hz")
    return parts.join(" · ")
  }

  function refresh() {
    if (!brightnessProbe.running) brightnessProbe.running = true
    if (!monitorProbe.running) monitorProbe.running = true
  }

  function toggle() {
    toggleRefresh()
  }

  Process {
    id: brightnessProbe
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") { s.brightnessAvailable = false; return }
        // device,class,current,percent,max
        var parts = raw.split(",")
        if (parts.length < 5) { s.brightnessAvailable = false; return }
        var pct = parseInt(String(parts[3]).replace("%", ""), 10)
        if (!isNaN(pct)) { s.brightnessAvailable = true; s.brightness = pct }
      }
    }
  }

  Process {
    id: brightnessSetter
    command: ["brightnessctl", "set", "1%"]
  }

  function setBrightness(pct) {
    var value = Math.max(1, Math.min(100, Math.round(Number(pct))))
    s.brightness = value
    brightnessSetter.command = ["brightnessctl", "set", value + "%"]
    if (!brightnessSetter.running) brightnessSetter.running = true
  }

  Process {
    id: monitorProbe
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var list = JSON.parse(text || "[]")
          if (!list.length) return
          var m = list[0]
          s.monitorName = String(m.name || "")
          s.monitorWidth = Number(m.width || 0)
          s.monitorHeight = Number(m.height || 0)
          s.monitorRefresh = Number(m.refreshRate || 0)
          s.monitorScale = Number(m.scale || 1)
          var modes = m.availableModes || []
          var has60 = false
          for (var i = 0; i < modes.length; i++) {
            var mode = String(modes[i])
            if (mode.indexOf("@60") !== -1 || mode.indexOf("@59") !== -1) { has60 = true; break }
          }
          // A custom 60 Hz mode is not in availableModes (the XPS panel
          // advertises only its native 120), so also allow the downshift
          // whenever the rate is above 60.
          s.supports60 = has60 || s.monitorRefresh > 60
        } catch (e) {
        }
      }
    }
  }

  Process {
    id: modeSetter
    command: ["true"]
  }

  function applyMode(mode) {
    if (!monitorName) return
    var script = "hl.monitor({ output = \"" + monitorName + "\", mode = \""
      + mode + "\", position = \"auto\", scale = " + monitorScale + " })"
    modeSetter.command = ["hyprctl", "eval", script]
    if (!modeSetter.running) modeSetter.running = true
    settleTimer.restart()
  }

  function toggleRefresh() {
    if (!supports60) return
    if (monitorRefresh >= 100) applyMode(monitorWidth + "x" + monitorHeight + "@60")
    else applyMode("preferred")
  }

  Timer {
    id: settleTimer
    interval: 900
    onTriggered: s.refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: s.refresh()
  }

  Component.onCompleted: refresh()
}
