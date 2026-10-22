import QtQuick
import Quickshell
import qs.Commons

// Display page, rendered by Deck and by this plugin's own popup.
//
// One monitor is the *target*: the one the switches and window actions act
// on. Placement is free: drag any display, and it snaps to the edges,
// corners and centre lines of the others, with guides showing what it
// latched onto. A layout where a display does not touch another one is
// flagged as invalid, as is an overlap.
Item {
  id: page

  property var state: null
  property var host: null

  // The monitor the switches act on. Empty means "follow the focused one".
  property string targetName: ""

  implicitHeight: col.implicitHeight

  readonly property real level: state ? Math.max(0, Math.min(1, state.brightness / 100)) : 0

  readonly property var target: {
    if (!state) return null
    var picked = targetName !== "" ? state.byName(targetName) : null
    if (picked && !picked.disabled) return picked
    return state.focusedMonitor
  }

  readonly property string selectedName: target ? target.name : ""
  onSelectedNameChanged: {
    rateOpen = false
    resolutionOpen = false
    scaleOpen = false
    if (state && selectedName !== "") state.probeBrightness(selectedName)
  }

  // Monitors the target can be compared with. A mirrored output is not part
  // of the desktop, so it is not part of the arrangement.
  readonly property var others: {
    if (!state || !target) return []
    var out = []
    var list = state.layoutMonitors
    for (var i = 0; i < list.length; i++)
      if (list[i].name !== target.name) out.push(list[i])
    return out
  }

  function select(name) { page.targetName = name }

  // Edits are staged, not applied. A drag records the target position here;
  // Apply pushes every staged display to Hyprland, Cancel throws them away.
  // Nothing touches the live arrangement until Apply is pressed.
  property var pending: ({})
  readonly property int pendingCount: {
    var n = 0
    for (var k in pending) n++
    return n
  }

  function posX(m) {
    return pending[m.name] !== undefined ? pending[m.name].x : m.x
  }
  function posY(m) {
    return pending[m.name] !== undefined ? pending[m.name].y : m.y
  }

  function stage(name, x, y, mode) {
    var p = {}
    for (var k in pending) p[k] = pending[k]
    var old = pending[name]
    p[name] = {
      x: x,
      y: y,
      mode: (mode !== undefined && mode !== null && String(mode) !== "")
        ? String(mode)
        : (old && old.mode ? old.mode : null)
    }
    pending = p
  }

  property bool rateOpen: false

  function pendingMode(m) {
    return (pending[m.name] && pending[m.name].mode) ? pending[m.name].mode : ""
  }
  function targetModeString() {
    if (!target || !state) return ""
    var pm = pendingMode(target)
    return pm !== "" ? pm : state.currentMode(target)
  }
  function targetRateLabel() {
    return state ? state.modeRateLabel(targetModeString()) : ""
  }
  function targetRates() {
    return (state && target) ? state.ratesFor(target.name) : []
  }
  function rateTextFor(m) {
    if (!state) return ""
    var pm = pendingMode(m)
    return pm !== "" ? state.modeRateLabel(pm) : (Math.round(Number(m.rate)) + " Hz")
  }
  readonly property var textStops: [9, 10, 11, 12, 14, 16, 20]
  property bool resolutionOpen: false
  property bool scaleOpen: false
  property bool textOpen: false

  function targetResolutions() {
    return (state && target) ? state.resolutionsFor(target.name) : []
  }
  function targetResolutionLabel() {
    if (!target) return ""
    var list = targetResolutions()
    for (var i = 0; i < list.length; i++)
      if (list[i].w === target.w && list[i].h === target.h) return list[i].label
    return target.w + "×" + target.h
  }
  function applyResolution(mode) {
    resolutionOpen = false
    if (!state || !target) return
    var m = state.byName(target.name)
    if (m) state.applyArrangement(target.name, m.x, m.y, mode, m.scale)
  }

  function targetScales() {
    return (state && target) ? state.scaleOptions(target.w, target.h) : []
  }
  function targetScaleLabel() {
    if (!state || !target) return ""
    return state.scaleLabel(state.cleanScale(target.scale, target.w, target.h))
  }
  function applyScale(value) {
    scaleOpen = false
    if (!state || !target) return
    var m = state.byName(target.name)
    if (m) state.applyArrangement(target.name, m.x, m.y, state.currentMode(m), value)
  }

  function currentTextSize() { return Style.font.baseSize }
  function setTextSize(px) {
    textOpen = false
    Quickshell.execDetached(["omarchy-display-text-size", String(px)])
  }

  // A rate is an explicit choice and trivially reversible, so it is applied
  // immediately. The position is the LIVE one: applying at posX/posY would
  // also apply a staged position that has not been confirmed.
  function applyRate(mode) {
    if (!state || !target) return
    rateOpen = false
    var m = state.byName(target.name)
    if (m) state.applyArrangement(target.name, m.x, m.y, mode)
  }

  function clearPending() { pending = ({}) }

  function applyPending() {
    if (!state || pendingCount === 0) return
    var entries = []
    var applied = ({})
    for (var k in pending) {
      var p = pending[k]
      var m = state.byName(k)
      entries.push({
        name: k, x: p.x, y: p.y,
        mode: p.mode ? p.mode : (m ? state.currentMode(m) : ""),
        scale: m ? m.scale : 1
      })
      applied[k] = true
    }
    // The displays that did not move are anchors: apply their final positions
    // too, or Hyprland can shift them out of the way when a staged monitor
    // lands next to them.
    var all = state.monitors
    for (var i = 0; i < all.length; i++) {
      var mm = all[i]
      if (applied[mm.name]) continue
      entries.push({
        name: mm.name, x: mm.x, y: mm.y,
        mode: state.currentMode(mm), scale: mm.scale
      })
    }
    state.applyLayout(entries)
    canvas.holdForApply()
  }

  // The host injects `state` after the page instance exists, so this is the
  // reliable moment to re-read: the page can open long after the last poll.
  onStateChanged: {
    if (!state) return
    state.refresh()
    if (selectedName !== "") state.probeBrightness(selectedName)
  }
  Component.onCompleted: if (state) state.refresh()

  // ----------------------------------------------------------------- chrome

  component Caps: Text {
    color: Util.alpha(Color.foreground, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1.5
  }

  component Rule: Rectangle {
    width: parent ? parent.width : 0
    height: 1
    color: Util.alpha(Color.foreground, 0.1)
  }

  component Head: Item {
    id: head
    property string glyph: ""
    property string title: ""
    property string value: ""
    property int gap: 0
    width: parent ? parent.width : 0
    height: Style.space(22) + gap

    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: Style.space(22)

      Text {
        id: headGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        text: head.glyph
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.left: headGlyph.right
        anchors.leftMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        text: head.title.toUpperCase()
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1.5
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: head.value
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // A collapsible section: a header row that toggles its body. The body of a
  // Section is where declared children go.
  component Section: Column {
    id: sec
    property string glyph: ""
    property string title: ""
    property string value: ""
    property bool expanded: true
    default property alias content: body.data
    width: parent ? parent.width : 0
    spacing: Style.space(2)

    Item {
      width: parent.width
      height: Style.space(24)

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sec.expanded = !sec.expanded
      }

      Text {
        id: secGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        text: sec.glyph
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.left: secGlyph.right
        anchors.leftMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        text: sec.title.toUpperCase()
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1.5
      }

      Text {
        id: secChevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: sec.expanded ? "▾" : "▸"
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: secChevron.left
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        text: sec.value
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: Style.space(2)
      visible: sec.expanded
    }
  }

  // A small action pill. Width follows its text so a monitor name can sit in
  // it without a hardcoded size.
  component Chip: Rectangle {
    id: chip
    property string label: ""
    signal picked()

    width: chipText.implicitWidth + Style.space(16)
    height: Style.space(22)
    radius: Style.cornerRadius
    property bool hovered: false
    color: chip.hovered ? Util.alpha(Color.accent, Style.hoverFillAlpha) : "transparent"
    border.width: 1
    border.color: Util.alpha(Color.foreground, chip.enabled ? Style.normalBorderAlpha : 0.12)

    Text {
      id: chipText
      anchors.centerIn: parent
      text: chip.label
      color: chip.enabled ? Color.foreground : Util.alpha(Color.foreground, 0.35)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: chip.hovered = true
      onExited: chip.hovered = false
      onClicked: chip.picked()
    }
  }

  // A switch, used for mirroring and for enabling a display.
  component Switch: Rectangle {
    id: sw
    property bool on: false
    signal toggled()

    width: Style.space(34)
    height: Style.space(18)
    radius: height / 2
    color: sw.on ? Util.alpha(Color.accent, 0.85) : Util.alpha(Color.foreground, 0.2)

    Rectangle {
      width: Style.space(14)
      height: width
      radius: width / 2
      y: (parent.height - height) / 2
      x: sw.on ? parent.width - width - Style.space(2) : Style.space(2)
      color: "#ffffff"
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: sw.toggled()
    }
  }

  Column {
    id: col
    width: parent.width
    spacing: Style.space(2)

    // ---- hero ----
    Item {
      width: parent.width
      height: Style.space(44)

      Text {
        id: heroGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(30)
        text: page.state ? page.state.icon : ""
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        horizontalAlignment: Text.AlignHCenter
      }

      Column {
        anchors.left: heroGlyph.right
        anchors.leftMargin: Style.space(10)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          width: parent.width
          text: page.target ? page.target.name : "Display"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }

        Caps {
          width: parent.width
          text: page.target
            ? (page.target.w + " × " + page.target.h + " · " + page.target.scale + "×")
            : ""
        }
      }
    }

    Rule { }

    // ---- every display: pick one, switch one off ----
    Section {
      id: displaysSection
      glyph: "☰"
      title: "Displays"
      value: page.state ? String(page.state.monitors.length) : "0"
      visible: page.state ? page.state.monitors.length > 1 : false

    Repeater {
      model: page.state ? page.state.monitors : []

      delegate: Item {
        required property var modelData

        readonly property bool current: page.target && modelData.name === page.target.name

        width: col.width
        height: Style.space(28)
        visible: (page.state ? page.state.monitors.length : 0) > 1

        Rectangle {
          anchors.fill: parent
          color: parent.current ? Util.alpha(Color.foreground, 0.06) : "transparent"
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (!modelData.disabled) page.select(modelData.name)
        }

        Text {
          id: nameText
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.name
          color: modelData.disabled
            ? Util.alpha(Color.foreground, 0.4)
            : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: parent.current
        }

        Caps {
          anchors.left: nameText.right
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.disabled
            ? "OFF"
            : (modelData.mirrorOf !== "none"
                ? "MIRROR · " + modelData.mirrorOf
                : modelData.w + "×" + modelData.h + " · " + page.rateTextFor(modelData))
        }

        Switch {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          on: !modelData.disabled
          onToggled: page.state.setDisabled(modelData.name, !modelData.disabled)
        }
      }
    }
      // Resolution, labelled by common aspect ratio. Picking one applies its
      // highest advertised rate immediately.
      Item {
        width: parent.width
        height: Style.space(30)
        visible: page.target && page.targetResolutions().length > 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: page.resolutionOpen = !page.resolutionOpen
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "Resolution"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: page.targetResolutionLabel() + "  ▾"
          color: Util.alpha(Color.foreground, 0.7)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Column {
        width: parent.width
        spacing: 0
        visible: page.resolutionOpen

        Repeater {
          model: page.targetResolutions()

          delegate: Item {
            required property var modelData
            readonly property bool current: page.target
              && modelData.w === page.target.w && modelData.h === page.target.h

            width: col.width
            height: Style.space(26)

            Rectangle {
              anchors.fill: parent
              color: parent.current
                ? Util.alpha(Color.accent, Style.selectedFillAlpha)
                : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(20)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: parent.current ? Color.accent : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: page.applyResolution(modelData.mode)
            }
          }
        }
      }

      // Refresh rate of the selected display, chosen from the modes the panel
      // actually advertises at its current resolution.
      Item {
        width: parent.width
        height: Style.space(30)
        visible: page.target && page.target.mirrorOf === "none"
          && page.targetRates().length > 0

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: page.rateOpen = !page.rateOpen
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "Refresh rate"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: page.targetRateLabel() + "  ▾"
          color: Util.alpha(Color.foreground, 0.7)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Column {
        width: parent.width
        spacing: 0
        visible: page.rateOpen

        Repeater {
          model: page.targetRates()

          delegate: Item {
            required property var modelData
            readonly property bool current: modelData.label === page.targetRateLabel()

            width: col.width
            height: Style.space(26)

            Rectangle {
              anchors.fill: parent
              color: parent.current
                ? Util.alpha(Color.accent, Style.selectedFillAlpha)
                : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(20)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: parent.current ? Color.accent : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: page.applyRate(modelData.mode)
            }
          }
        }
      }

      // Scale presets, cleaned to values Hyprland accepts for this mode.
      Item {
        width: parent.width
        height: Style.space(30)
        visible: page.target && page.targetScales().length > 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: page.scaleOpen = !page.scaleOpen
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "Scale"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: page.targetScaleLabel() + "  ▾"
          color: Util.alpha(Color.foreground, 0.7)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Column {
        width: parent.width
        spacing: 0
        visible: page.scaleOpen

        Repeater {
          model: page.targetScales()

          delegate: Item {
            required property var modelData
            readonly property bool current: page.target
              && Math.abs(modelData.value
                 - page.state.cleanScale(page.target.scale, page.target.w, page.target.h)) < 0.001

            width: col.width
            height: Style.space(26)

            Rectangle {
              anchors.fill: parent
              color: parent.current
                ? Util.alpha(Color.accent, Style.selectedFillAlpha)
                : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(20)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: parent.current ? Color.accent : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: page.applyScale(modelData.value)
            }
          }
        }
      }

    // ---- mirroring ----
    Item {
      width: parent.width
      height: Style.space(30)
      visible: page.others.length > 0

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "Mirror " + (page.target ? page.target.name : "")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      Switch {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        on: page.target ? page.target.mirrorOf !== "none" : false
        onToggled: {
          if (!page.state || !page.target || !page.others.length) return
          if (page.target.mirrorOf !== "none") page.state.unmirror(page.target.name)
          else page.state.mirrorTo(page.target.name, page.others[0].name)
        }
      }
    }

    }

    Rule { visible: displaysSection.visible }

    // ---- brightness ----
    Section {
      id: brightnessSection
      glyph: "☼"
      title: "Brightness"
      visible: page.state && page.target && page.state.brightnessAvailable
        && page.state.brightnessMonitor === page.target.name

    Item {
      width: parent.width
      height: Style.space(24)
      visible: page.state && page.target && page.state.brightnessAvailable
        && page.state.brightnessMonitor === page.target.name

      Text {
        id: levelGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        text: "☼"
        color: Util.alpha(Color.foreground, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        id: levelValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(34)
        horizontalAlignment: Text.AlignRight
        text: page.state ? page.state.brightness + "%" : ""
        color: Util.alpha(Color.foreground, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Item {
        anchors.left: levelGlyph.right
        anchors.leftMargin: Style.space(8)
        anchors.right: levelValue.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(18)

        Rectangle {
          id: track
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: 3
          radius: 2
          color: Util.alpha(Color.foreground, 0.18)

          Rectangle {
            width: track.width * page.level
            height: parent.height
            radius: 2
            color: Color.accent
          }
        }

        Rectangle {
          width: 9
          height: 9
          radius: 5
          color: Color.accent
          x: Math.max(0, Math.min(track.width, track.width * page.level)) - width / 2
          anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
          anchors.fill: parent
          preventStealing: true
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) { if (page.state) page.state.setBrightness(Math.round(mouse.x / width * 100)) }
          onPositionChanged: function(mouse) {
            if (pressed && page.state) page.state.setBrightness(Math.round(mouse.x / width * 100))
          }
        }
      }
    }
    }

    Rule { visible: brightnessSection.visible }

    // ---- text size (global: shell, GTK and terminals) ----
    Section {
      id: textSizeSection
      glyph: "A"
      title: "Text size"

      Item {
        width: parent.width
        height: Style.space(30)

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: page.textOpen = !page.textOpen
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "Size"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: Math.round(page.currentTextSize()) + " px  ▾"
          color: Util.alpha(Color.foreground, 0.7)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Column {
        width: parent.width
        spacing: 0
        visible: page.textOpen

        Repeater {
          model: page.textStops

          delegate: Item {
            required property var modelData
            readonly property bool current: Math.round(modelData) === Math.round(page.currentTextSize())

            width: col.width
            height: Style.space(26)

            Rectangle {
              anchors.fill: parent
              color: parent.current
                ? Util.alpha(Color.accent, Style.selectedFillAlpha)
                : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(20)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData + " px"
              color: parent.current ? Color.accent : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: page.setTextSize(modelData)
            }
          }
        }
      }
    }

    Rule { }

    // ---- layout preview, free drag with guides ----
    Head {
      glyph: "▭"
      title: "Layout"
      value: page.state ? String(page.state.layoutMonitors.length) : "0"
      gap: Style.space(4)
    }

    Item {
      id: canvas
      width: parent.width
      height: Style.space(160)
      clip: true

      // The state replaces its monitor array on every poll, even when
      // nothing moved. Feeding that straight into a Repeater destroys and
      // recreates every delegate, which kills an in-flight drag. The view is
      // a snapshot, refreshed only when the values actually change and never
      // while a drag is running.
      readonly property var live: page.state ? page.state.layoutMonitors : []
      property var view: []
      property bool pendingViewSync: false
      property bool pendingValid: true

      // The viewport follows the live arrangement, and a staged position only
      // once the staged layout is valid. An invalid placement must not drag
      // the whole preview out to chase it.
      function fitX(m) {
        return (pendingValid && page.pending[m.name] !== undefined) ? page.posX(m) : m.x
      }
      function fitY(m) {
        return (pendingValid && page.pending[m.name] !== undefined) ? page.posY(m) : m.y
      }
      readonly property real pad: Style.space(4)

      // Snap distances, in screen pixels. An edge connection is generous, a
      // corner is tighter, and a centre line is tighter still: on displays
      // of different sizes the centre can sit close to an edge, and it must
      // not steal an edge connection.
      readonly property real edgeSnapPx: 12
      readonly property real cornerSnapPx: 8
      readonly property real centreSnapPx: 5
      readonly property real holdFactor: 1.5
      readonly property int holdMs: 160
      readonly property real minOverlap: 32

      // ---- world bounds and transform ----
      readonly property real minX: {
        var v = 0; var first = true
        for (var i = 0; i < view.length; i++) { if (first || canvas.fitX(view[i]) < v) { v = canvas.fitX(view[i]); first = false } }
        return first ? 0 : v
      }
      readonly property real minY: {
        var v = 0; var first = true
        for (var i = 0; i < view.length; i++) { if (first || canvas.fitY(view[i]) < v) { v = canvas.fitY(view[i]); first = false } }
        return first ? 0 : v
      }
      readonly property real spanW: {
        var maxX = minX
        for (var i = 0; i < view.length; i++)
          maxX = Math.max(maxX, canvas.fitX(view[i]) + page.state.logicalW(view[i]))
        return Math.max(1, maxX - minX)
      }
      readonly property real spanH: {
        var maxY = minY
        for (var i = 0; i < view.length; i++)
          maxY = Math.max(maxY, canvas.fitY(view[i]) + page.state.logicalH(view[i]))
        return Math.max(1, maxY - minY)
      }

      // The panel is narrow, so half a display of room on each side is the
      // compromise: enough to pull a display clear of the arrangement in any
      // direction, without shrinking the preview to the point where a drag
      // cannot be aimed.
      readonly property real maxW: {
        var v = 1
        for (var i = 0; i < view.length; i++) v = Math.max(v, page.state.logicalW(view[i]))
        return v
      }
      readonly property real maxH: {
        var v = 1
        for (var i = 0; i < view.length; i++) v = Math.max(v, page.state.logicalH(view[i]))
        return v
      }
      readonly property real worldW: spanW + maxW
      readonly property real worldH: spanH + maxH

      readonly property real availW: Math.max(1, width - 2 * pad)
      readonly property real availH: Math.max(1, height - 2 * pad)
      // fit is the zoom that shows the whole arrangement with its margins.
      // scale is what is actually drawn, and it is the only value the
      // transform, the rectangle sizes and the snap distances use.
      readonly property real fit: Math.max(0.0001, Math.min(availW / worldW, availH / worldH))
      // The fit follows the arrangement, which can change on its own; animate
      // it so a refit is a move, not a jump. Zoom stays immediate.
      property real fitAnimated: fit
      property bool fitSeen: false
      Behavior on fitAnimated {
        enabled: canvas.fitSeen
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
      property real zoom: 1
      readonly property real scale: Math.max(0.0001, fitAnimated * zoom)
      readonly property real offsetX: (width - spanW * scale) / 2
      readonly property real offsetY: (height - spanH * scale) / 2

      function canvasX(wx) { return offsetX + basePanX + overflowX + (wx - minX) * scale }
      function canvasY(wy) { return offsetY + basePanY + overflowY + (wy - minY) * scale }
      function worldX(cx) { return (cx - offsetX - basePanX - overflowX) / scale + minX }
      function worldY(cy) { return (cy - offsetY - basePanY - overflowY) / scale + minY }

      readonly property bool panned: Math.abs(basePanX) > 0.5 || Math.abs(basePanY) > 0.5

      function resetView() {
        zoom = 1
        basePanX = 0
        basePanY = 0
        overflowX = 0
        overflowY = 0
      }

      // Zoom about a point in canvas coordinates, so the display under the
      // pointer stays under it.
      function zoomAt(factor, px, py) {
        if (dragging) return
        var nz = Math.max(0.25, Math.min(6, zoom * factor))
        if (Math.abs(nz - zoom) < 0.0001) return
        var wx = worldX(px)
        var wy = worldY(py)
        var ns = fitAnimated * nz
        var nox = (width - spanW * ns) / 2
        var noy = (height - spanH * ns) / 2
        basePanX = px - nox - (wx - minX) * ns
        basePanY = py - noy - (wy - minY) * ns
        zoom = nz
        overflowX = 0
        overflowY = 0
      }

      // ---- drag state ----
      property bool dragging: false
      property string dragName: ""
      property var dragItem: null
      property bool moved: false
      property real startItemX: 0
      property real startItemY: 0
      property real pressSceneX: 0
      property real pressSceneY: 0
      // basePan is the user's manual pan of the preview. overflow is the
      // transient shift added while a drag pushes past an edge; it is reset
      // when the drag settles, the user's pan is not.
      property real basePanX: 0
      property real basePanY: 0
      property real overflowX: 0
      property real overflowY: 0
      Behavior on overflowX {
        enabled: !canvas.dragging
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
      Behavior on overflowY {
        enabled: !canvas.dragging
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
      property real freeX: 0
      property real freeY: 0
      property real dropX: 0
      property real dropY: 0

      // ---- snap state ----
      property bool locked: false
      property var lockedSnap: null
      property real outSince: 0
      property bool hasGuideX: false
      property bool hasGuideY: false
      property real guideX: 0
      property real guideY: 0
      property string statusText: "Drag a display"
      property string statusCoords: ""
      property string invalidText: ""

      Timer {
        id: graceTimer
        interval: canvas.holdMs + 30
        onTriggered: canvas.releaseHeld()
      }

      Timer {
        id: settleDrag
        interval: 1100
        onTriggered: {
          canvas.dragging = false
          canvas.locked = false
          canvas.lockedSnap = null
          canvas.outSince = 0
          canvas.overflowX = 0
          canvas.overflowY = 0
          canvas.syncView()
          canvas.refreshValidity("", 0, 0)
        }
      }

      // On Apply, keep the bindings off until the compositor has reported the
      // new positions, so the preview cannot fall back to the old state for a
      // frame. The staged copy is dropped once that refresh has landed.
      Timer {
        id: pendingClear
        interval: 1200
        onTriggered: {
          page.clearPending()
          canvas.refreshValidity("", 0, 0)
        }
      }

      function holdForApply() {
        dragging = true
        graceTimer.stop()
        settleDrag.restart()
        pendingClear.restart()
      }

      function cancelStaged() {
        settleDrag.stop()
        pendingClear.stop()
        dragging = false
        dragItem = null
        dragName = ""
        locked = false
        lockedSnap = null
        outSince = 0
        hasGuideX = false
        hasGuideY = false
        overflowX = 0
        overflowY = 0
        syncView()
        refreshValidity("", 0, 0)
      }


      function sameView(a, b) {
        if (a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
          if (a[i].name !== b[i].name || a[i].x !== b[i].x || a[i].y !== b[i].y ||
              a[i].w !== b[i].w || a[i].h !== b[i].h || a[i].scale !== b[i].scale)
            return false
        }
        return true
      }

      function syncView() {
        if (dragging) { pendingViewSync = true; return }
        pendingViewSync = false
        // A display can disappear (unplugged, disabled, mirrored); its staged
        // position must not linger and be applied to a screen that is gone.
        var names = {}
        for (var i = 0; i < live.length; i++) names[live[i].name] = true
        var pruned = {}
        var dropped = false
        for (var k in page.pending) {
          if (names[k]) pruned[k] = page.pending[k]
          else dropped = true
        }
        if (dropped) page.pending = pruned
        if (sameView(live, view)) return
        view = live.slice()
      }

      onLiveChanged: {
        syncView()
        refreshValidity("", 0, 0)
        if (!canvas.fitSeen && canvas.view.length > 0) canvas.fitSeen = true
      }

      Component.onCompleted: syncView()

      // ------------------------------------------------------ snap geometry

      function rectsOverlap(a, b) {
        return Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) > 1 &&
               Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) > 1
      }

      function touches(a, b) {
        var xo = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)
        var yo = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y)
        var vertical = (Math.abs(a.x + a.w - b.x) < 1 || Math.abs(b.x + b.w - a.x) < 1) && yo > 1
        var horizontal = (Math.abs(a.y + a.h - b.y) < 1 || Math.abs(b.y + b.h - a.y) < 1) && xo > 1
        var corner = (Math.abs(a.x + a.w - b.x) < 1 || Math.abs(b.x + b.w - a.x) < 1) &&
                     (Math.abs(a.y + a.h - b.y) < 1 || Math.abs(b.y + b.h - a.y) < 1)
        return vertical || horizontal || corner
      }

      function overlapsAt(name, x, y) {
        var w = 0
        var h = 0
        for (var i = 0; i < view.length; i++) {
          if (view[i].name === name) {
            w = page.state.logicalW(view[i])
            h = page.state.logicalH(view[i])
            break
          }
        }
        if (w === 0) return false
        for (var j = 0; j < view.length; j++) {
          var o = view[j]
          if (o.name === name) continue
          if (rectsOverlap({ x: x, y: y, w: w, h: h },
                           { x: page.posX(o), y: page.posY(o), w: page.state.logicalW(o), h: page.state.logicalH(o) }))
            return true
        }
        return false
      }

      function refreshValidity(dragName, dx, dy) {
        var rects = []
        for (var i = 0; i < view.length; i++) {
          var m = view[i]
          rects.push({
            name: m.name,
            x: (dragName !== "" && m.name === dragName) ? dx : page.posX(m),
            y: (dragName !== "" && m.name === dragName) ? dy : page.posY(m),
            w: page.state.logicalW(m),
            h: page.state.logicalH(m)
          })
        }
        var issues = []
        for (var a = 0; a < rects.length; a++)
          for (var b = a + 1; b < rects.length; b++)
            if (rectsOverlap(rects[a], rects[b]))
              issues.push(rects[a].name + " overlaps " + rects[b].name)
        if (rects.length > 1) {
          for (var k = 0; k < rects.length; k++) {
            var attached = false
            for (var j = 0; j < rects.length; j++)
              if (j !== k && touches(rects[k], rects[j])) { attached = true; break }
            if (!attached) issues.push(rects[k].name + " is not touching any display")
          }
        }
        invalidText = issues.join(" · ")
        if (!dragging)
          pendingValid = (page.pendingCount === 0) || (issues.length === 0)
      }

      // ------------------------------------------------------ candidates
      //
      // A candidate is a complete placement relative to one other display,
      // not an independent per-axis rule. A snap therefore always produces a
      // touching placement. `xg`/`yg` are the guide lines to draw, or null.

      function cand(x, y, xg, yg, xType, yType, other) {
        return { x: x, y: y, xg: xg, yg: yg, xType: xType, yType: yType, other: other }
      }

      function candidatesFor(D, O, freeX, freeY) {
        var out = []
        var dw = page.state.logicalW(D)
        var dh = page.state.logicalH(D)
        var ow = page.state.logicalW(O)
        var oh = page.state.logicalH(O)

        var ox = page.posX(O)
        var oy = page.posY(O)
        var yAligned = [
          [oy, oy, "top edges"],
          [oy + oh - dh, oy + oh, "bottom edges"],
          [oy + (oh - dh) / 2, oy + oh / 2, "centred"]
        ]
        var xAligned = [
          [ox, ox, "left edges"],
          [ox + ow - dw, ox + ow, "right edges"],
          [ox + (ow - dw) / 2, ox + ow / 2, "centred"]
        ]
        var yOverlaps = freeY < oy + oh && freeY + dh > oy
        var xOverlaps = freeX < ox + ow && freeX + dw > ox

        for (var i = 0; i < yAligned.length; i++) {
          var ya = yAligned[i]
          out.push(cand(ox + ow, ya[0], ox + ow, ya[1], "flush right", ya[2], O.name))
          out.push(cand(ox - dw, ya[0], ox, ya[1], "flush left", ya[2], O.name))
        }
        if (yOverlaps) {
          out.push(cand(ox + ow, freeY, ox + ow, null, "flush right", null, O.name))
          out.push(cand(ox - dw, freeY, ox, null, "flush left", null, O.name))
        } else if (freeY >= oy + oh || freeY + dh <= oy) {
          // Just past either end of the edge: clamp into a minimum overlap,
          // so the connection is still an edge with length, not a point.
          var yPast = freeY >= oy + oh
            ? oy + oh - minOverlap
            : oy - dh + minOverlap
          out.push(cand(ox + ow, yPast, ox + ow, null, "flush right", null, O.name))
          out.push(cand(ox - dw, yPast, ox, null, "flush left", null, O.name))
        }

        for (var j = 0; j < xAligned.length; j++) {
          var xa = xAligned[j]
          out.push(cand(xa[0], oy + oh, xa[1], oy + oh, xa[2], "flush below", O.name))
          out.push(cand(xa[0], oy - dh, xa[1], oy, xa[2], "flush above", O.name))
        }
        if (xOverlaps) {
          out.push(cand(freeX, oy + oh, null, oy + oh, null, "flush below", O.name))
          out.push(cand(freeX, oy - dh, null, oy, null, "flush above", O.name))
        } else if (freeX >= ox + ow || freeX + dw <= ox) {
          var xPast = freeX >= ox + ow
            ? ox + ow - minOverlap
            : ox - dw + minOverlap
          out.push(cand(xPast, oy + oh, null, oy + oh, null, "flush below", O.name))
          out.push(cand(xPast, oy - dh, null, oy, null, "flush above", O.name))
        }

        // Corner to corner: both edges flush, corners meet at a point.
        out.push(cand(ox + ow, oy + oh, ox + ow, oy + oh,
                      "flush right", "flush below", O.name))
        out.push(cand(ox - dw, oy + oh, ox, oy + oh,
                      "flush left", "flush below", O.name))
        out.push(cand(ox + ow, oy - dh, ox + ow, oy,
                      "flush right", "flush above", O.name))
        out.push(cand(ox - dw, oy - dh, ox, oy,
                      "flush left", "flush above", O.name))

        return out
      }

      function limitsFor(c, factor) {
        var e = edgeSnapPx * factor / scale
        var k = cornerSnapPx * factor / scale
        var m = centreSnapPx * factor / scale
        if (c.xg !== null && c.yg !== null) {
          if (c.xType === "centred" || c.yType === "centred") {
            return {
              x: (c.xType === "centred" ? m : e),
              y: (c.yType === "centred" ? m : e)
            }
          }
          return { x: k, y: k }
        }
        return { x: e, y: e }
      }

      function isCorner(c) {
        return c.xg !== null && c.yg !== null &&
               c.xType !== "centred" && c.yType !== "centred"
      }

      function bestCandidate(D, freeX, freeY, factor) {
        var dw = page.state.logicalW(D)
        var dh = page.state.logicalH(D)
        var near = []
        for (var i = 0; i < view.length; i++) {
          var O = view[i]
          if (O.name === D.name) continue
          var cs = candidatesFor(D, O, freeX, freeY)
          for (var j = 0; j < cs.length; j++) {
            var c = cs[j]
            var lim = limitsFor(c, factor)
            if (Math.abs(c.x - freeX) <= lim.x && Math.abs(c.y - freeY) <= lim.y)
              near.push(c)
          }
        }

        // Prefer placements that latch both axes (a corner), then the closest.
        near.sort(function(a, b) {
          var sa = (a.xg !== null ? 1 : 0) + (a.yg !== null ? 1 : 0)
          var sb = (b.xg !== null ? 1 : 0) + (b.yg !== null ? 1 : 0)
          if (sa !== sb) return sb - sa
          return (Math.abs(a.x - freeX) + Math.abs(a.y - freeY)) -
                 (Math.abs(b.x - freeX) + Math.abs(b.y - freeY))
        })

        for (var k = 0; k < near.length; k++) {
          var cc = near[k]
          var hits = false
          for (var q = 0; q < view.length; q++) {
            var oo = view[q]
            if (oo.name === D.name) continue
            if (rectsOverlap({ x: cc.x, y: cc.y, w: dw, h: dh },
                             { x: page.posX(oo), y: page.posY(oo), w: page.state.logicalW(oo), h: page.state.logicalH(oo) })) {
              hits = true
              break
            }
          }
          if (!hits) return cc
        }
        return null
      }

      function freeResult(x, y) {
        return { x: x, y: y, xg: null, yg: null, xType: null, yType: null, other: "" }
      }

      // Acquire at the normal limits. While held, re-evaluate at the wider
      // release limits so the free axis still follows the pointer. A quick
      // excursion outside even that is a shake, not a release, until it has
      // lasted `holdMs`.
      function computeSnap(D, freeX, freeY) {
        var res = bestCandidate(D, freeX, freeY, 1)
        if (res) {
          lockedSnap = res
          locked = true
          outSince = 0
          graceTimer.stop()
          return res
        }
        if (locked && lockedSnap) {
          res = bestCandidate(D, freeX, freeY, holdFactor)
          if (res) {
            lockedSnap = res
            outSince = 0
            graceTimer.stop()
            return res
          }
          var now = Date.now()
          if (outSince === 0) outSince = now
          if (now - outSince < holdMs) {
            graceTimer.restart()
            return lockedSnap
          }
          locked = false
          outSince = 0
          lockedSnap = null
          graceTimer.stop()
        }
        return freeResult(freeX, freeY)
      }

      function releaseHeld() {
        if (!locked || !dragging || !dragItem) return
        if (outSince === 0 || Date.now() - outSince < holdMs) return
        dragItem.x = canvasX(freeX)
        dragItem.y = canvasY(freeY)
        dropX = freeX
        dropY = freeY
        locked = false
        outSince = 0
        lockedSnap = null
        hasGuideX = false
        hasGuideY = false
        statusText = "free position"
        statusCoords = Math.round(freeX) + ", " + Math.round(freeY)
        refreshValidity(dragName, freeX, freeY)
      }

      function applySnap(res) {
        hasGuideX = res.xg !== null
        hasGuideY = res.yg !== null
        if (hasGuideX) guideX = canvasX(res.xg)
        if (hasGuideY) guideY = canvasY(res.yg)

        var parts = []
        if (res.xType) parts.push(res.xType + " → " + res.other)
        if (res.yType) parts.push(res.yType + " → " + res.other)
        var corner = isCorner(res)
        statusText = corner
          ? "corner · " + parts.join(" · ")
          : (parts.length ? "snapped · " + parts.join(" · ") : "free position")
        statusCoords = Math.round(res.x) + ", " + Math.round(res.y)
      }

      function beginDrag(m, item) {
        // A previous drop is still holding its bindings off for a moment;
        // a new drag must cancel that or it would switch dragging off under
        // the pointer mid-drag.
        settleDrag.stop()
        dragging = true
        dragName = m.name
        dragItem = item
        moved = false
        locked = false
        lockedSnap = null
        outSince = 0
        hasGuideX = false
        hasGuideY = false
        graceTimer.stop()
      }

      // Overflow: when the display reaches an edge of the preview, pan the
      // view instead of stopping the drag. The display stays at the edge and
      // its world position keeps following the pointer, so a snap position
      // outside the original viewport is still reachable.
      function moveDragTo(m, item, nx, ny) {
        var margin = Style.space(4)
        var loX = margin
        var hiX = width - margin - item.width
        var loY = margin
        var hiY = height - margin - item.height
        if (nx < loX) { overflowX -= (nx - loX); nx = loX }
        else if (nx > hiX) { overflowX -= (nx - hiX); nx = hiX }
        if (ny < loY) { overflowY -= (ny - loY); ny = loY }
        else if (ny > hiY) { overflowY -= (ny - hiY); ny = hiY }
        item.x = nx
        item.y = ny
        moveDrag(m, item)
      }

      function moveDrag(m, item) {
        if (Math.abs(item.x - startItemX) > 2 || Math.abs(item.y - startItemY) > 2)
          moved = true
        freeX = worldX(item.x)
        freeY = worldY(item.y)
        var res = computeSnap(m, freeX, freeY)
        dropX = res.x
        dropY = res.y
        item.x = canvasX(res.x)
        item.y = canvasY(res.y)
        applySnap(res)
        refreshValidity(m.name, res.x, res.y)
      }

      function endDrag(m) {
        graceTimer.stop()
        if (!moved) {
          dragging = false
          dragItem = null
          dragName = ""
          hasGuideX = false
          hasGuideY = false
          overflowX = 0
          overflowY = 0
          syncView()
          return
        }
        page.stage(m.name, dropX, dropY)
        dragItem = null
        dragName = ""
        hasGuideX = false
        hasGuideY = false
        dragging = false
        overflowX = 0
        overflowY = 0
        syncView()
        refreshValidity("", 0, 0)
      }

      WheelHandler {
        onWheel: function(event) {
          if (canvas.dragging) return
          canvas.zoomAt(event.angleDelta.y > 0 ? 1.15 : 1 / 1.15, event.x, event.y)
          event.accepted = true
        }
      }

      Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.foreground, 0.03)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.12)
      }

      // Drag the empty part of the preview to pan it. The displays are drawn
      // above this and handle their own presses.
      MouseArea {
        id: panArea
        anchors.fill: parent
        preventStealing: true
        cursorShape: panArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real pressX: 0
        property real pressY: 0
        property real startPanX: 0
        property real startPanY: 0

        onPressed: function(mouse) {
          var p = mapToItem(null, mouse.x, mouse.y)
          pressX = p.x
          pressY = p.y
          startPanX = canvas.basePanX
          startPanY = canvas.basePanY
        }

        onPositionChanged: function(mouse) {
          if (!pressed) return
          var p = mapToItem(null, mouse.x, mouse.y)
          canvas.basePanX = startPanX + (p.x - pressX)
          canvas.basePanY = startPanY + (p.y - pressY)
        }
      }

      Repeater {
        id: monitorRepeater
        model: canvas.view

        delegate: Rectangle {
          id: mon
          required property var modelData

          readonly property bool current: page.target && modelData.name === page.target.name
          readonly property bool overlapping: canvas.dragging && canvas.dragName === modelData.name
            ? canvas.overlapsAt(modelData.name, canvas.dropX, canvas.dropY)
            : false

          z: canvas.dragItem === mon ? 3 : 1

          // x and y are owned by a Binding, not a plain binding: during a
          // drag the Binding is off and the drag writes x/y directly, which
          // an ordinary binding would overwrite on the next re-evaluate.
          // RestoreNone is load-bearing: Binding defaults to restoring the
          // value the property had before the binding, which is 0. Without
          // it the display jumps to the top-left of the preview the moment a
          // drag starts.
          Binding {
            target: mon
            property: "x"
            value: canvas.canvasX(page.posX(modelData))
            when: !canvas.dragging
            restoreMode: Binding.RestoreNone
          }
          Binding {
            target: mon
            property: "y"
            value: canvas.canvasY(page.posY(modelData))
            when: !canvas.dragging
            restoreMode: Binding.RestoreNone
          }

          width: Math.max(1, page.state.logicalW(modelData) * canvas.scale)
          height: Math.max(1, page.state.logicalH(modelData) * canvas.scale)
          radius: Style.cornerRadius
          color: overlapping
            ? Util.alpha(Color.urgent, 0.14)
            : current
              ? Util.alpha(Color.accent, Style.selectedFillAlpha)
              : Util.alpha(Color.foreground, 0.06)
          border.width: 1
          border.color: overlapping
            ? Color.urgent
            : current
              ? Util.alpha(Color.accent, 0.55)
              : Util.alpha(Color.foreground, 0.25)

          Text {
            anchors.centerIn: parent
            text: modelData.name
            color: parent.current ? Color.accent : Util.alpha(Color.foreground, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width - Style.space(4)
            horizontalAlignment: Text.AlignHCenter
          }

          MouseArea {
            id: dragArea
            anchors.fill: parent
            // The page lives in a ScrollView; without this the flickable
            // steals the grab as soon as the pointer moves and the display
            // never follows it.
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            // No drag.target: Qt's own drag moves the item from the pointer
            // delta and would overwrite the snapped position depending on
            // handler ordering. The pointer delta is applied here, the snap
            // is computed, and the snapped position is what stays.
            onPressed: function(mouse) {
              var p = dragArea.mapToItem(null, mouse.x, mouse.y)
              canvas.pressSceneX = p.x
              canvas.pressSceneY = p.y
              canvas.startItemX = mon.x
              canvas.startItemY = mon.y
              canvas.beginDrag(modelData, mon)
              page.select(modelData.name)
            }

            onPositionChanged: function(mouse) {
              if (!pressed) return
              var p = dragArea.mapToItem(null, mouse.x, mouse.y)
              canvas.moveDragTo(modelData, mon,
                canvas.startItemX + (p.x - canvas.pressSceneX),
                canvas.startItemY + (p.y - canvas.pressSceneY))
            }

            onReleased: canvas.endDrag(modelData)
          }
        }
      }

      // Guides are drawn above the displays. The marker is where the two
      // alignment lines cross, which is the corner or centre that latched.
      Rectangle {
        visible: canvas.hasGuideX
        x: canvas.guideX
        y: 0
        width: 1
        height: canvas.height
        color: Util.alpha(Color.accent, 0.9)
        z: 5
      }
      Rectangle {
        visible: canvas.hasGuideY
        x: 0
        y: canvas.guideY
        width: canvas.width
        height: 1
        color: Util.alpha(Color.accent, 0.9)
        z: 5
      }
      Rectangle {
        visible: canvas.hasGuideX && canvas.hasGuideY
        x: canvas.guideX - Style.space(3)
        y: canvas.guideY - Style.space(3)
        width: Style.space(6)
        height: Style.space(6)
        color: Color.accent
        z: 6
      }
    }

    // ---- invalid layout ----
    Rectangle {
      width: parent.width
      height: canvas.invalidText !== "" ? Style.space(26) : 0
      visible: canvas.invalidText !== ""
      color: Util.alpha(Color.urgent, 0.08)

      Text {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        verticalAlignment: Text.AlignVCenter
        text: "Invalid layout · " + canvas.invalidText
        color: Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    // ---- drag status ----
    Item {
      width: parent.width
      height: Style.space(16)
      visible: page.state ? page.state.layoutMonitors.length > 1 : false

      Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: Style.space(70)
        anchors.verticalCenter: parent.verticalCenter
        text: canvas.statusText
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: canvas.statusCoords
        color: Util.alpha(Color.foreground, 0.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    // View controls are pinned to the right edge. Fit is inserted to their
    // left, so showing it does not shift the zoom buttons.
    Item {
      width: parent.width
      height: Style.space(26)

      Row {
        anchors.right: parent.right
        spacing: Style.space(6)

        Chip {
          visible: canvas.panned || canvas.zoom !== 1
          label: "Fit"
          onPicked: canvas.resetView()
        }
        Chip {
          label: "−"
          onPicked: canvas.zoomAt(1 / 1.15, canvas.width / 2, canvas.height / 2)
        }
        Chip {
          label: "+"
          onPicked: canvas.zoomAt(1.15, canvas.width / 2, canvas.height / 2)
        }
      }
    }

    // Confirming a staged edit has its own line below the view controls, so
    // the zoom buttons never move when it appears.
    Row {
      width: parent.width
      height: Style.space(26)
      spacing: Style.space(6)
      visible: page.pendingCount > 0

      Text {
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text: "Pending changes"
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Chip {
        label: canvas.invalidText !== "" ? "Apply anyway" : "Apply"
        onPicked: page.applyPending()
      }
      Chip {
        label: "Cancel"
        onPicked: {
          page.clearPending()
          canvas.cancelStaged()
        }
      }
    }

  }
}
