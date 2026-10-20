import QtQuick
import Quickshell
import qs.Commons

// Deck adapter. The five members Deck reads, forwarded to the shared State.
// The page is handed `state` by Deck (see Deck's docs/CONTRACT.md), so tile and
// page read the same object.
//
// tileFull shows what the half tile cannot: one line per monitor, with its
// name, resolution and rate. A display has no single on/off, so a tap on the
// tile opens the page.
Item {
  id: s

  readonly property var state: stateLoader.item

  // A display has no on/off; a selected fill would claim a state it lacks.
  readonly property bool active: false
  readonly property string label: state ? state.label : ""
  readonly property string detail: state ? state.detail : ""
  readonly property string icon: state ? state.icon : ""

  function openPage() {
    Quickshell.execDetached(["omarchy-shell", "mutex-solutions.deck", "openSection", "display"])
  }

  readonly property Component tileFull: fullTile

  Component {
    id: fullTile

    Item {
      id: full
      readonly property var st: s.state
      readonly property var screens: st ? st.enabledMonitors : []

      MouseArea {
        anchors.fill: parent
        onClicked: s.openPage()
      }

      Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        text: "☼"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }

      Column {
        anchors.left: glyph.right
        anchors.leftMargin: Style.space(11)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: "Display"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Repeater {
          model: full.screens

          delegate: Text {
            required property var modelData
            width: parent.width
            text: String(modelData.name || "") + "   "
              + modelData.w + "×" + modelData.h + "   "
              + Math.round(modelData.rate) + " Hz"
            color: Util.alpha(Color.foreground, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        Text {
          visible: full.screens.length === 0
          width: parent.width
          text: "No display detected"
          color: Util.alpha(Color.foreground, 0.45)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Loader {
    id: stateLoader
    source: "../State.qml"
  }
}
