import QtQuick
import qs.Commons

// Display page, rendered by Deck and by this plugin's own popup.
Item {
  id: page

  property var state: null
  property var host: null

  implicitHeight: col.implicitHeight

  readonly property real level: state ? Math.max(0, Math.min(1, state.brightness / 100)) : 0

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
          text: page.state && page.state.monitorName !== ""
            ? page.state.monitorName
            : "Display"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }

        Caps {
          width: parent.width
          text: page.state
            ? (page.state.monitorWidth + " × " + page.state.monitorHeight
               + " · " + page.state.monitorScale + "×")
            : ""
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
        id: volGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        text: "☼"
        color: Util.alpha(Color.foreground, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        id: volValue
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
        anchors.left: volGlyph.right
        anchors.leftMargin: Style.space(8)
        anchors.right: volValue.left
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

    Rule { }

    // ---- refresh ----
    Head {
      glyph: "▭"
      title: "Refresh"
      value: page.state ? Math.round(page.state.monitorRefresh) + " Hz" : ""
      gap: Style.space(4)
    }

    Item {
      width: parent.width
      height: Style.space(30)
      visible: page.state ? page.state.supports60 : false

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(22)
        spacing: Style.space(6)

        Repeater {
          model: [60, 120]

          delegate: Rectangle {
            required property int modelData
            width: Style.space(54)
            height: Style.space(22)
            radius: Style.cornerRadius
            readonly property bool on: page.state
              ? (modelData >= 100 ? page.state.monitorRefresh >= 100 : page.state.monitorRefresh < 100)
              : false
            color: on ? Util.alpha(Color.accent, Style.selectedFillAlpha) : "transparent"
            border.width: 1
            border.color: on ? Util.alpha(Color.accent, 0.55) : Util.alpha(Color.foreground, Style.normalBorderAlpha)

            Text {
              anchors.centerIn: parent
              text: modelData + " Hz"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!page.state) return
                if (modelData >= 100) page.state.applyMode("preferred")
                else page.state.applyMode(page.state.monitorWidth + "x" + page.state.monitorHeight + "@60")
              }
            }
          }
        }
      }
    }

    Text {
      visible: page.state ? !page.state.supports60 : false
      width: parent.width
      height: Style.space(26)
      verticalAlignment: Text.AlignVCenter
      leftPadding: Style.space(8)
      text: "This display offers one refresh rate"
      color: Util.alpha(Color.foreground, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
