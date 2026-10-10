import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar-Button + Popup für RGB Sync. Alle Änderungen laufen über das CLI
// (bin/omarchy-rgb), damit Hook, Service und Panel dieselbe Logik teilen.
Panel {
  id: root
  moduleName: "raimo.rgb-sync"
  ipcTarget: "raimo.rgb-sync"

  readonly property string cli: Quickshell.env("HOME") + "/.config/omarchy/plugins/raimo.rgb-sync/bin/omarchy-rgb"
  readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/omarchy-rgb/state.json"

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var cfg: ({})
  property var state: ({})
  property var palette: []
  property bool busy: actionProc.running
  property var queued: null

  readonly property bool enabled: cfg.enabled !== false
  readonly property string source: cfg.source || "wallpaper"
  readonly property string ledColor: state.color ? "#" + state.color : "transparent"
  readonly property var sourceLabels: ({ wallpaper: "Hintergrund", theme: "Theme", fixed: "Feste Farbe" })

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function ingest(text) {
    try {
      var s = JSON.parse(text)
      root.cfg = s.config || {}
      root.state = s.state || {}
      root.palette = s.palette || []
    } catch (e) {}
  }

  // Optimistisch lokal setzen, dann ans CLI geben (das gleich neu synchronisiert)
  function setValue(key, value) {
    var next = Object.assign({}, root.cfg)
    next[key] = value
    root.cfg = next
    run(["set", key, String(value)])
  }

  function run(args) {
    var cmd = [root.cli].concat(args)
    if (actionProc.running) { root.queued = cmd; return }
    actionProc.command = cmd
    actionProc.running = true
  }

  function pickSwatch(entry) {
    if (root.source === "theme") root.setValue("themeKey", entry.key)
    else root.setValue("fixedColor", entry.color)
  }

  function swatchActive(entry) {
    if (root.source === "theme") return root.cfg.themeKey === entry.key
    return String(root.cfg.fixedColor || "").toUpperCase() === entry.color
  }

  function timeLabel() {
    if (!state.updated) return ""
    return "Zuletzt " + state.updated.replace("T", " ").slice(5, 16)
  }

  onOpenedChanged: if (opened) refresh()
  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [root.cli, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.ingest(text) }
  }

  Process {
    id: actionProc
    onExited: {
      if (root.queued) {
        actionProc.command = root.queued
        root.queued = null
        actionProc.running = true
        return
      }
      root.refresh()
    }
  }

  // Bar-Punkt aktualisieren, wenn Hook oder Service synchronisiert haben
  FileView {
    path: root.stateFile
    watchChanges: true
    onFileChanged: { reload(); root.refresh() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏘"
    slotSize: Style.bar.iconSlot
    tooltipText: root.enabled ? "RGB: " + root.ledColor : "RGB aus"
    onPressed: function (b) {
      if (b === Qt.RightButton) root.setValue("enabled", !root.enabled)
      else root.toggle()
    }

    // Kleiner Punkt in der aktuellen LED-Farbe
    Rectangle {
      width: Style.space(6)
      height: width
      radius: width / 2
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(3)
      color: root.enabled ? root.ledColor : "transparent"
      border.width: root.enabled ? 0 : 1
      border.color: root.fg
      opacity: root.enabled ? 1 : 0.5
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: Farbfeld · Titel/Status · An/Aus ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(swatch.height, heroLabels.implicitHeight)

          Rectangle {
            id: swatch
            width: Style.space(44)
            height: width
            radius: Style.cornerRadius > 0 ? width / 2 : 0
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.enabled ? root.ledColor : "transparent"
            border.width: 1
            border.color: Util.alpha(root.fg, 0.3)
            Behavior on color { ColorAnimation { duration: 300 } }
          }

          Column {
            id: heroLabels
            anchors.left: swatch.right
            anchors.leftMargin: Style.space(14)
            anchors.right: power.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "RGB-Beleuchtung"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: (root.busy ? "Wird angewendet…"
                    : !root.enabled ? "Aus"
                    : (root.ledColor + " · " + root.sourceLabels[root.source])).toUpperCase()
              color: Qt.darker(root.fg, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ToggleSwitch {
            id: power
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.enabled
            busy: root.busy
            foreground: root.fg
            onToggled: root.setValue("enabled", !root.enabled)
          }
        }

        Text {
          visible: root.state.ok === false && !!root.state.error
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "⚠ " + (root.state.error || "")
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        PanelSeparator { foreground: root.fg }

        // ---------- Quelle ----------
        Column {
          width: parent.width
          spacing: Style.space(10)
          opacity: root.enabled ? 1 : 0.45

          PanelSectionHeader { text: "QUELLE"; foreground: root.fg; fontFamily: root.fontFamily }

          Row {
            id: sourceRow
            width: parent.width
            spacing: Style.space(6)
            readonly property var items: [
              { id: "wallpaper", icon: "󰸉", label: "Hintergrund" },
              { id: "theme", icon: "󰏘", label: "Theme" },
              { id: "fixed", icon: "󰝤", label: "Fest" }
            ]

            Repeater {
              model: sourceRow.items
              Button {
                required property var modelData
                width: (sourceRow.width - sourceRow.spacing * 2) / 3
                iconText: modelData.icon
                iconSize: Style.font.title
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.fg
                fontFamily: root.fontFamily
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.source === modelData.id
                onClicked: root.setValue("source", modelData.id)
              }
            }
          }
        }

        // ---------- Farbe aus dem Theme (Theme- und Fest-Modus) ----------
        Column {
          visible: root.source !== "wallpaper" && root.palette.length > 0
          width: parent.width
          spacing: Style.space(10)
          opacity: root.enabled ? 1 : 0.45

          PanelSectionHeader {
            text: root.source === "theme" ? "THEMEFARBE" : "FARBE AUS DEM THEME"
            foreground: root.fg
            fontFamily: root.fontFamily
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.palette
              Rectangle {
                required property var modelData
                width: Style.space(26)
                height: width
                radius: Style.cornerRadius > 0 ? width / 2 : 0
                color: modelData.color
                border.width: root.swatchActive(modelData) ? 2 : 1
                border.color: root.swatchActive(modelData) ? root.fg : Util.alpha(root.fg, 0.25)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.pickSwatch(modelData)
                }
              }
            }
          }
        }

        // ---------- Regler ----------
        Column {
          width: parent.width
          spacing: Style.space(8)
          opacity: root.enabled ? 1 : 0.45

          SliderRow {
            visible: root.source !== "fixed"
            label: "Sättigung"
            key: "saturation"
          }
          SliderRow {
            label: "Helligkeit"
            key: "brightness"
          }
        }

        PanelSeparator { foreground: root.fg }

        Item {
          width: parent.width
          implicitHeight: syncButton.implicitHeight

          Text {
            anchors.left: parent.left
            anchors.right: syncButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.timeLabel()
            elide: Text.ElideRight
            color: root.fg
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Button {
            id: syncButton
            anchors.right: parent.right
            iconText: "󰑐"
            iconSpinning: root.busy
            text: "Neu anwenden"
            fontSize: Style.font.bodySmall
            foreground: root.fg
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.run(["sync", "--force"])
          }
        }
      }
    }
  }

  component SliderRow: Row {
    id: sliderRow
    property string label: ""
    property string key: ""
    readonly property real current: root.cfg[key] !== undefined ? Number(root.cfg[key]) : 1

    width: parent.width
    spacing: Style.space(10)

    Text {
      width: Style.space(80)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: sliderRow.label
      color: root.fg
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    PanelSlider {
      id: slider
      bar: root.bar
      width: parent.width - Style.space(80) - Style.space(44) - parent.spacing * 2
      anchors.verticalCenter: parent.verticalCenter
      value: sliderRow.current
      minimum: 0.1
      maximum: 1
      onReleased: function (v) { root.setValue(sliderRow.key, Math.round(v * 100) / 100) }
    }

    Text {
      width: Style.space(44)
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: Math.round((slider.dragging ? slider.liveValue : sliderRow.current) * 100) + "%"
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
