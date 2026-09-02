import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "pilppilo.gemini-usage"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool showLabel: Boolean(setting("showLabel", false))

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.service = service
  }

  implicitWidth: root.showLabel && !root.vertical
    ? Math.max(Style.bar.iconSlot, contentRow.implicitWidth + Style.space(16))
    : Style.bar.iconSlot
  implicitHeight: Style.bar.iconSlot

  onBarChanged: injectPanel()

  Service {
    id: service
    settings: root.settings
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { service.refresh(); return "ok" }
    function status(): string {
      return JSON.stringify({
        refreshing: service.refreshing,
        data: service.usageData,
        error: service.lastError
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    labelVisible: false
    fixedWidth: root.implicitWidth
    fixedHeight: root.implicitHeight
    tooltipText: "Gemini / Antigravity usage: " +
      Model.formatPercent((service.usageData && service.usageData.session) ? service.usageData.session.percent : 0) +
      " used · click for details, right-click to refresh"
    active: Boolean((service.usageData && service.usageData.session && service.usageData.session.percent >= 0.85) || (service.usageData && service.usageData.behindPace))

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) {
        service.refresh()
      } else if (buttonCode === Qt.LeftButton) {
        root.toggle()
      }
    }

    // Centered content: compact icon-only by default, or expanded pill when showLabel is enabled
    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Image {
        anchors.verticalCenter: parent.verticalCenter
        source: Qt.resolvedUrl("assets/gemini.svg")
        sourceSize.width: Style.bar.iconCanvas
        sourceSize.height: Style.bar.iconCanvas
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showLabel && !root.vertical
        text: Model.formatPercent((service.usageData && service.usageData.session) ? service.usageData.session.percent : 0)
        color: (service.usageData && service.usageData.session && service.usageData.session.percent >= 0.85) ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showLabel && !root.vertical && Boolean(service.usageData && service.usageData.session && service.usageData.session.resetRemainingSeconds > 0)
        text: "· " + Model.formatCountdown((service.usageData && service.usageData.session) ? service.usageData.session.resetRemainingSeconds : 0)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 1
      }
    }
  }
}
