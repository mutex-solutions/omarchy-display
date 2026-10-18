import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons

// Standalone bar widget. Click opens the panel; the same page Deck renders is
// shown inside it.
Panel {
  id: root

  moduleName: "mutex-solutions.display"
  ipcTarget: "mutex-solutions.display"

  readonly property var state: stateLoader.item

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: stateLoader
    source: "State.qml"
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.state ? root.state.icon : ""
    active: root.state ? root.state.active : false
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight, Style.space(520)), Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.close()
    }

    // Long network lists must scroll; a Column alone would overflow and clip.
    ScrollView {
      id: scroll
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: content
        width: scroll.availableWidth
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Style.space(24)

          Text {
            id: headerGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "☼"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
          }

          Text {
            anchors.left: headerGlyph.right
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: "Display"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(34)
            height: Style.space(18)
            radius: height / 2
            color: root.state && root.state.active
              ? Util.alpha(Color.accent, 0.85)
              : Util.alpha(Color.foreground, 0.2)

            Rectangle {
              width: Style.space(14)
              height: width
              radius: width / 2
              y: (parent.height - height) / 2
              x: root.state && root.state.active ? parent.width - width - Style.space(2) : Style.space(2)
              color: "#ffffff"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.state) root.state.toggle()
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.foreground, 0.12)
        }
        Loader {
          id: pageLoader
          width: parent.width
          active: root.opened
          source: "deck/Page.qml"
          onLoaded: if (item) item.state = root.state
        }
      }
    }
  }

  onStateChanged: if (pageLoader.item) pageLoader.item.state = root.state

  // Re-read on open: brightness can be changed from the keyboard while the
  // panel is closed, and a stale slider is worse than a short delay.
  onOpenedChanged: {
    if (root.opened && root.state)
      root.state.refresh()
  }
}
