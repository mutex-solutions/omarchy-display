import QtQuick
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

  // The host injects `state` after the page instance exists, so this is the
  // reliable moment to re-read: the page can open long after the last poll.
  onStateChanged: if (state) state.refresh()
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

      readonly property var list: page.state ? page.state.layoutMonitors : []
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

      // The panel is narrow, so half a display of room on each side is the
      // compromise: enough to pull a display clear of the arrangement in any
      // direction, without shrinking the preview to the point where a drag
      // cannot be aimed.
      readonly property real maxW: {
        var v = 1
        for (var i = 0; i < list.length; i++) v = Math.max(v, page.state.logicalW(list[i]))
        return v
      }
      readonly property real maxH: {
        var v = 1
        for (var i = 0; i < list.length; i++) v = Math.max(v, page.state.logicalH(list[i]))
        return v
      }
      readonly property real worldW: spanW + maxW
      readonly property real worldH: spanH + maxH

      readonly property real availW: Math.max(1, width - 2 * pad)
      readonly property real availH: Math.max(1, height - 2 * pad)
      readonly property real fit: Math.max(0.0001, Math.min(availW / worldW, availH / worldH))
      readonly property real offsetX: (width - spanW * fit) / 2
      readonly property real offsetY: (height - spanH * fit) / 2

      function canvasX(wx) { return offsetX + (wx - minX) * fit }
      function canvasY(wy) { return offsetY + (wy - minY) * fit }
      function worldX(cx) { return (cx - offsetX) / fit + minX }
      function worldY(cy) { return (cy - offsetY) / fit + minY }

      // ---- drag state ----
      property bool dragging: false
      property string dragName: ""
      property var dragItem: null
      property bool moved: false
      property real startItemX: 0
      property real startItemY: 0
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
        }
      }

      onListChanged: canvas.refreshValidity("", 0, 0)

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
        for (var i = 0; i < list.length; i++) {
          if (list[i].name === name) {
            w = page.state.logicalW(list[i])
            h = page.state.logicalH(list[i])
            break
          }
        }
        if (w === 0) return false
        for (var j = 0; j < list.length; j++) {
          var o = list[j]
          if (o.name === name) continue
          if (rectsOverlap({ x: x, y: y, w: w, h: h },
                           { x: o.x, y: o.y, w: page.state.logicalW(o), h: page.state.logicalH(o) }))
            return true
        }
        return false
      }

      function refreshValidity(dragName, dx, dy) {
        var rects = []
        for (var i = 0; i < list.length; i++) {
          var m = list[i]
          rects.push({
            name: m.name,
            x: (dragName !== "" && m.name === dragName) ? dx : m.x,
            y: (dragName !== "" && m.name === dragName) ? dy : m.y,
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

        var yAligned = [
          [O.y, O.y, "top edges"],
          [O.y + oh - dh, O.y + oh, "bottom edges"],
          [O.y + (oh - dh) / 2, O.y + oh / 2, "centred"]
        ]
        var xAligned = [
          [O.x, O.x, "left edges"],
          [O.x + ow - dw, O.x + ow, "right edges"],
          [O.x + (ow - dw) / 2, O.x + ow / 2, "centred"]
        ]
        var yOverlaps = freeY < O.y + oh && freeY + dh > O.y
        var xOverlaps = freeX < O.x + ow && freeX + dw > O.x

        for (var i = 0; i < yAligned.length; i++) {
          var ya = yAligned[i]
          out.push(cand(O.x + ow, ya[0], O.x + ow, ya[1], "flush right", ya[2], O.name))
          out.push(cand(O.x - dw, ya[0], O.x, ya[1], "flush left", ya[2], O.name))
        }
        if (yOverlaps) {
          out.push(cand(O.x + ow, freeY, O.x + ow, null, "flush right", null, O.name))
          out.push(cand(O.x - dw, freeY, O.x, null, "flush left", null, O.name))
        } else if (freeY >= O.y + oh || freeY + dh <= O.y) {
          // Just past either end of the edge: clamp into a minimum overlap,
          // so the connection is still an edge with length, not a point.
          var yPast = freeY >= O.y + oh
            ? O.y + oh - minOverlap
            : O.y - dh + minOverlap
          out.push(cand(O.x + ow, yPast, O.x + ow, null, "flush right", null, O.name))
          out.push(cand(O.x - dw, yPast, O.x, null, "flush left", null, O.name))
        }

        for (var j = 0; j < xAligned.length; j++) {
          var xa = xAligned[j]
          out.push(cand(xa[0], O.y + oh, xa[1], O.y + oh, xa[2], "flush below", O.name))
          out.push(cand(xa[0], O.y - dh, xa[1], O.y, xa[2], "flush above", O.name))
        }
        if (xOverlaps) {
          out.push(cand(freeX, O.y + oh, null, O.y + oh, null, "flush below", O.name))
          out.push(cand(freeX, O.y - dh, null, O.y, null, "flush above", O.name))
        } else if (freeX >= O.x + ow || freeX + dw <= O.x) {
          var xPast = freeX >= O.x + ow
            ? O.x + ow - minOverlap
            : O.x - dw + minOverlap
          out.push(cand(xPast, O.y + oh, null, O.y + oh, null, "flush below", O.name))
          out.push(cand(xPast, O.y - dh, null, O.y, null, "flush above", O.name))
        }

        // Corner to corner: both edges flush, corners meet at a point.
        out.push(cand(O.x + ow, O.y + oh, O.x + ow, O.y + oh,
                      "flush right", "flush below", O.name))
        out.push(cand(O.x - dw, O.y + oh, O.x, O.y + oh,
                      "flush left", "flush below", O.name))
        out.push(cand(O.x + ow, O.y - dh, O.x + ow, O.y,
                      "flush right", "flush above", O.name))
        out.push(cand(O.x - dw, O.y - dh, O.x, O.y,
                      "flush left", "flush above", O.name))

        return out
      }

      function limitsFor(c, factor) {
        var e = edgeSnapPx * factor / fit
        var k = cornerSnapPx * factor / fit
        var m = centreSnapPx * factor / fit
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
        for (var i = 0; i < list.length; i++) {
          var O = list[i]
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
          for (var q = 0; q < list.length; q++) {
            var oo = list[q]
            if (oo.name === D.name) continue
            if (rectsOverlap({ x: cc.x, y: cc.y, w: dw, h: dh },
                             { x: oo.x, y: oo.y, w: page.state.logicalW(oo), h: page.state.logicalH(oo) })) {
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
          return
        }
        page.state.moveTo(m.name, dropX, dropY)
        dragItem = null
        dragName = ""
        hasGuideX = false
        hasGuideY = false
        settleDrag.restart()
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
          id: mon
          required property var modelData

          readonly property bool current: page.target && modelData.name === page.target.name
          readonly property bool overlapping: canvas.dragging && canvas.dragName === modelData.name
            ? canvas.overlapsAt(modelData.name, canvas.dropX, canvas.dropY)
            : false

          z: dragArea.drag.active ? 3 : 1

          // x and y are owned by a Binding, not a plain binding: during a
          // drag the Binding is off and the drag writes x/y directly, which
          // an ordinary binding would overwrite on the next re-evaluate.
          Binding {
            target: mon
            property: "x"
            value: canvas.canvasX(modelData.x)
            when: !canvas.dragging
          }
          Binding {
            target: mon
            property: "y"
            value: canvas.canvasY(modelData.y)
            when: !canvas.dragging
          }

          width: Math.max(16, page.state.logicalW(modelData) * canvas.fit)
          height: Math.max(12, page.state.logicalH(modelData) * canvas.fit)
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
            cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: mon
            drag.axis: Drag.XandYAxis
            drag.minimumX: 0
            drag.maximumX: Math.max(0, canvas.width - mon.width)
            drag.minimumY: 0
            drag.maximumY: Math.max(0, canvas.height - mon.height)

            onPressed: {
              canvas.startItemX = mon.x
              canvas.startItemY = mon.y
              canvas.beginDrag(modelData, mon)
              page.select(modelData.name)
            }

            onPositionChanged: {
              if (pressed) canvas.moveDrag(modelData, mon)
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

    // ---- every display: pick one, switch one off ----
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
