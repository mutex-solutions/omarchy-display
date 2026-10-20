import QtQuick
import qs.Commons

// Display page, rendered by Deck and by this plugin's own popup.
//
// One monitor is the *target*: the one the controls act on. It starts as the
// focused output and can be picked from the layout preview or the list below.
// Placement is chosen spatially: the boxes around the reference monitor are
// the eight places the target can go.
Item {
  id: page

  property var state: null
  property var host: null

  // The monitor the controls act on. Empty means "follow the focused one".
  property string targetName: ""

  implicitHeight: col.implicitHeight

  readonly property real level: state ? Math.max(0, Math.min(1, state.brightness / 100)) : 0

  readonly property var target: {
    if (!state) return null
    var picked = targetName !== "" ? state.byName(targetName) : null
    if (picked && !picked.disabled) return picked
    return state.focusedMonitor
  }

  // Monitors the target can be arranged against. A mirrored output is not
  // part of the desktop, so while one is active the arrange controls step
  // aside instead of offering a position that would silently undo the mirror.
  readonly property var others: {
    if (!state || !target) return []
    var out = []
    var list = state.layoutMonitors
    for (var i = 0; i < list.length; i++)
      if (list[i].name !== target.name) out.push(list[i])
    return out
  }

  readonly property var reference: others.length ? others[0] : null

  // Where the focused window can go: every screen except the one it is
  // already on. Using the selected target here would offer a move to the
  // window's own monitor whenever that monitor happens to be selected.
  readonly property var moveTargets: {
    if (!state) return []
    var out = []
    var from = state.activeWindowMonitorName
    var list = state.enabledMonitors
    for (var i = 0; i < list.length; i++)
      if (list[i].name !== from) out.push(list[i])
    return out
  }

  readonly property var windowTarget: moveTargets.length ? moveTargets[0] : null

  function select(name) { page.targetName = name }

  // ------------------------------------------------------------- placement
  //
  // Eight slots: the four edges and the four corners around the reference
  // monitor. Edge slots centre the target on that edge; corner slots sit the
  // target diagonally outside the corner. Hyprland's auto-* positions only
  // cover the edges and align rather than centre, so these are explicit
  // logical-pixel positions computed from the sizes the compositor reports.

  function applySlot(id) {
    if (!state || !target || !reference) return
    var tw = state.logicalW(target)
    var th = state.logicalH(target)
    var ow = state.logicalW(reference)
    var oh = state.logicalH(reference)
    var x = reference.x
    var y = reference.y
    if (id.indexOf("e") >= 0) x = reference.x + ow
    else if (id.indexOf("w") >= 0) x = reference.x - tw
    else x = reference.x + Math.round((ow - tw) / 2)
    if (id.indexOf("n") >= 0) y = reference.y - th
    else if (id.indexOf("s") >= 0) y = reference.y + oh
    else y = reference.y + Math.round((oh - th) / 2)
    state.moveTo(target.name, x, y)
  }

  // Which slot the target currently occupies, so the clicked one stays lit.
  // Matched by side rather than by pixels: an auto-right position is aligned
  // to the top edge, while the slot is centred, and both are the same answer.
  function currentSlot() {
    var t = target
    var o = reference
    if (!t || !o) return ""
    var tw = state.logicalW(t)
    var th = state.logicalH(t)
    var ow = state.logicalW(o)
    var oh = state.logicalH(o)
    var h = t.x >= o.x + ow - 1 ? "e" : (t.x + tw <= o.x + 1 ? "w" : "")
    var v = t.y >= o.y + oh - 1 ? "s" : (t.y + th <= o.y + 1 ? "n" : "")
    if (h && v) return v + h
    return h || v
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
        text: "☼"
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

    // ---- layout preview with the eight placement slots ----
    Head {
      glyph: "▭"
      title: "Layout"
      value: page.state ? String(page.state.enabledMonitors.length) : "0"
      gap: Style.space(4)
    }

    Item {
      id: canvas
      width: parent.width
      height: Style.space(96)

      readonly property var list: page.state ? page.state.layoutMonitors : []
      readonly property real slotSize: Style.space(14)
      readonly property real slotGap: Style.space(4)
      readonly property real margin: slotSize + slotGap

      readonly property real minX: {
        var v = 0; var first = true
        for (var i = 0; i < list.length; i++) { if (first || list[i].x < v) { v = list[i].x; first = false } }
        return first ? 0 : v
      }
      readonly property real minY: {
        var v = 0; var first = true
        for (var i = 0; i < list.length; i++) { if (first || list[i].y < v) { v = list[i].y; first = false } }
        return first ? 0 : v
      }
      readonly property real spanW: {
        var maxX = minX
        for (var i = 0; i < list.length; i++)
          maxX = Math.max(maxX, list[i].x + page.state.logicalW(list[i]))
        return Math.max(1, maxX - minX)
      }
      readonly property real spanH: {
        var maxY = minY
        for (var i = 0; i < list.length; i++)
          maxY = Math.max(maxY, list[i].y + page.state.logicalH(list[i]))
        return Math.max(1, maxY - minY)
      }

      readonly property real availW: Math.max(1, width - 2 * margin)
      readonly property real availH: Math.max(1, height - 2 * margin)
      readonly property real fit: Math.min(availW / spanW, availH / spanH)
      readonly property real offsetX: margin + (availW - spanW * fit) / 2
      readonly property real offsetY: margin + (availH - spanH * fit) / 2

      function rectFor(m) {
        if (!m) return null
        return Qt.rect(offsetX + (m.x - minX) * fit,
                       offsetY + (m.y - minY) * fit,
                       Math.max(16, page.state.logicalW(m) * fit),
                       Math.max(12, page.state.logicalH(m) * fit))
      }

      readonly property var refRect: page.reference ? rectFor(page.reference) : null

      function slotRect(id) {
        var r = refRect
        if (!r) return Qt.rect(0, 0, 0, 0)
        var s = slotSize
        var g = slotGap
        var x = r.x + (r.width - s) / 2
        var y = r.y + (r.height - s) / 2
        if (id.indexOf("e") >= 0) x = r.x + r.width + g
        else if (id.indexOf("w") >= 0) x = r.x - s - g
        if (id.indexOf("n") >= 0) y = r.y - s - g
        else if (id.indexOf("s") >= 0) y = r.y + r.height + g
        return Qt.rect(x, y, s, s)
      }

      // A slot that a monitor already occupies is not an offer: that screen
      // is there. Monitor rectangles are translucent, so the slot would show
      // through and read as a button inside the screen.
      function slotCovered(id) {
        var s = slotRect(id)
        for (var i = 0; i < list.length; i++) {
          var r = rectFor(list[i])
          if (!r) continue
          if (s.x < r.x + r.width && s.x + s.width > r.x
              && s.y < r.y + r.height && s.y + s.height > r.y)
            return true
        }
        return false
      }

      Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.foreground, 0.03)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.12)
      }

      Repeater {
        model: canvas.list

        delegate: Rectangle {
          required property var modelData

          readonly property bool current: page.target && modelData.name === page.target.name

          // A slot can sit exactly where a monitor already is (the monitor is
          // in that position). The monitor must win, or its rectangle looks
          // like a button and cannot be clicked to select it.
          z: 1

          x: canvas.offsetX + (modelData.x - canvas.minX) * canvas.fit
          y: canvas.offsetY + (modelData.y - canvas.minY) * canvas.fit
          width: Math.max(16, page.state.logicalW(modelData) * canvas.fit)
          height: Math.max(12, page.state.logicalH(modelData) * canvas.fit)
          radius: Style.cornerRadius
          color: current
            ? Util.alpha(Color.accent, Style.selectedFillAlpha)
            : Util.alpha(Color.foreground, 0.06)
          border.width: 1
          border.color: current ? Util.alpha(Color.accent, 0.55) : Util.alpha(Color.foreground, 0.25)

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
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.select(modelData.name)
          }
        }
      }

      Repeater {
        model: ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

        delegate: Rectangle {
          id: slot
          required property string modelData

          readonly property var r: canvas.slotRect(modelData)
          readonly property bool current: page.currentSlot() === modelData
          property bool hovered: false

          visible: canvas.refRect !== null && !canvas.slotCovered(modelData)
          x: r.x
          y: r.y
          width: r.width
          height: r.height
          radius: Style.cornerRadius
          color: current
            ? Util.alpha(Color.accent, Style.selectedFillAlpha)
            : (hovered ? Util.alpha(Color.accent, 0.12) : Util.alpha(Color.foreground, 0.03))
          border.width: 1
          border.color: current || hovered
            ? Util.alpha(Color.accent, 0.6)
            : Util.alpha(Color.foreground, 0.22)

          Text {
            anchors.centerIn: parent
            text: "+"
            color: slot.current ? Color.accent : Util.alpha(Color.foreground, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: slot.hovered = true
            onExited: slot.hovered = false
            onClicked: page.applySlot(slot.modelData)
          }
        }
      }
    }

    Caps {
      width: parent.width
      height: Style.space(16)
      visible: page.others.length > 0
      horizontalAlignment: Text.AlignHCenter
      text: page.target ? ("Place " + page.target.name + " in a box") : ""
    }

    // ---- every display: pick one to arrange, switch one off ----
    Head {
      glyph: "☰"
      title: "Displays"
      value: page.state ? String(page.state.monitors.length) : "0"
      gap: Style.space(4)
      visible: page.state ? page.state.monitors.length > 1 : false
    }

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
                : modelData.w + "×" + modelData.h + " · " + Math.round(modelData.rate) + " Hz")
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

    Rule { }

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

    Rule { }

    // ---- windows ----
    Head {
      glyph: "▣"
      title: "Windows"
      gap: Style.space(2)
      visible: page.moveTargets.length > 0 || page.others.length > 0
    }

    // Move the focused window to the other monitor. A window belongs to a
    // workspace, and a workspace belongs to a monitor, so this moves it to
    // the workspace that screen is already showing.
    Item {
      width: parent.width
      height: Style.space(28)
      visible: page.others.length > 0

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.right: moveChip.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: page.state && page.state.activeWindowTitle !== ""
          ? page.state.activeWindowTitle
          : "No focused window"
        color: page.state && page.state.activeWindowTitle !== ""
          ? Color.foreground
          : Util.alpha(Color.foreground, 0.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Chip {
        id: moveChip
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        label: page.windowTarget ? "→ " + page.windowTarget.name : "→"
        enabled: !!(page.state && page.state.activeWindowTitle !== "" && page.windowTarget)
        onPicked: if (page.windowTarget) page.state.moveActiveWindowTo(page.windowTarget.name)
      }
    }

    // Swap every window between the two screens at once. This swaps the
    // active workspaces, so it is the entire desktop that moves, not one
    // window, and it is its own undo.
    Item {
      width: parent.width
      height: Style.space(28)
      visible: page.others.length > 0

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.right: swapChip.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "Swap screens"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Chip {
        id: swapChip
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        label: "⇄ " + (page.reference ? page.reference.name : "")
        enabled: !!(page.target && page.reference)
        onPicked: if (page.target && page.reference)
          page.state.swapScreens(page.target.name, page.reference.name)
      }
    }

    Rule { }

    // ---- brightness ----
    Head {
      glyph: "☼"
      title: "Brightness"
      visible: page.state ? page.state.brightnessAvailable : false
      gap: Style.space(4)
    }

    Item {
      width: parent.width
      height: Style.space(24)
      visible: page.state ? page.state.brightnessAvailable : false

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
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) { if (page.state) page.state.setBrightness(Math.round(mouse.x / width * 100)) }
          onPositionChanged: function(mouse) {
            if (pressed && page.state) page.state.setBrightness(Math.round(mouse.x / width * 100))
          }
        }
      }
    }
  }
}
