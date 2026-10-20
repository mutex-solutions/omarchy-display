import QtQuick
import qs.Commons

// Display page, rendered by Deck and by this plugin's own popup.
//
// One monitor is the *target*: the one the controls act on. It starts as the
// focused output and can be picked from the layout preview or the list below.
// Positions are relative (auto-left/right/up/down), so the arrangement stays
// correct with three or more screens.
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

  function select(name) { page.targetName = name }

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

  // A pill used by the arrange row.
  component Choice: Rectangle {
    id: choice
    property string label: ""
    property bool selected: false
    signal picked()

    width: Style.space(58)
    height: Style.space(24)
    radius: Style.cornerRadius
    color: choice.selected ? Util.alpha(Color.accent, Style.selectedFillAlpha) : "transparent"
    border.width: 1
    border.color: choice.selected
      ? Util.alpha(Color.accent, 0.55)
      : Util.alpha(Color.foreground, Style.normalBorderAlpha)

    Text {
      anchors.centerIn: parent
      text: choice.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: choice.picked()
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

  // Which side of the other monitors this one currently sits on.
  function sideOf(m) {
    if (!m || !others.length) return ""
    var o = others[0]
    var mw = state.logicalW(m)
    var mh = state.logicalH(m)
    var ow = state.logicalW(o)
    var oh = state.logicalH(o)
    if (m.x >= o.x + ow - 1) return "right"
    if (m.x + mw <= o.x + 1) return "left"
    if (m.y + mh <= o.y + 1) return "up"
    if (m.y >= o.y + oh - 1) return "down"
    return ""
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

    // ---- layout preview ----
    Head {
      glyph: "▭"
      title: "Layout"
      value: page.state ? String(page.state.enabledMonitors.length) : "0"
      gap: Style.space(6)
    }

    Item {
      id: canvas
      width: parent.width
      height: Style.space(92)

      readonly property var list: page.state ? page.state.layoutMonitors : []
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
      readonly property real fit: Math.min((width - 8) / spanW, (height - 8) / spanH)
      readonly property real offsetX: (width - spanW * fit) / 2
      readonly property real offsetY: (height - spanH * fit) / 2

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

    // ---- arrange the target relative to the others ----
    Head {
      glyph: "⇄"
      title: "Position"
      value: page.target ? page.target.name : ""
      gap: Style.space(6)
      visible: page.others.length > 0
    }

    Row {
      width: parent.width
      height: Style.space(28)
      spacing: Style.space(6)
      visible: page.others.length > 0

      Choice {
        label: "Left"
        selected: page.sideOf(page.target) === "left"
        onPicked: if (page.state && page.target) page.state.placeRelative(page.target.name, "left")
      }
      Choice {
        label: "Right"
        selected: page.sideOf(page.target) === "right"
        onPicked: if (page.state && page.target) page.state.placeRelative(page.target.name, "right")
      }
      Choice {
        label: "Above"
        selected: page.sideOf(page.target) === "up"
        onPicked: if (page.state && page.target) page.state.placeRelative(page.target.name, "up")
      }
      Choice {
        label: "Below"
        selected: page.sideOf(page.target) === "down"
        onPicked: if (page.state && page.target) page.state.placeRelative(page.target.name, "down")
      }
    }

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
