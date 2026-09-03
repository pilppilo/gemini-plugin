import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "gemini-usage"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool showLabel: Boolean(setting("showLabel", false))

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  readonly property bool isUrgent: {
    if (!service || !service.usageData) return false
    var cats = service.usageData.categories
    if (cats) {
      if (cats.gemini && ((cats.gemini.session && cats.gemini.session.percent >= 0.85) || cats.gemini.behindPace)) return true
      if (cats.claude_others && ((cats.claude_others.session && cats.claude_others.session.percent >= 0.85) || cats.claude_others.behindPace)) return true
    }
    return Boolean((service.usageData.session && service.usageData.session.percent >= 0.85) || service.usageData.behindPace)
  }

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
    tooltipText: {
      if (!service.usageData || !service.usageData.categories) {
        return "Gemini & Antigravity usage · click for details"
      }
      var g = service.usageData.categories.gemini
      var c = service.usageData.categories.claude_others
      var gP = Model.formatPercent(g && g.session ? g.session.percent : 0)
      var cP = Model.formatPercent(c && c.session ? c.session.percent : 0)
      return "Gemini: " + gP + " (5h) · Claude/Others: " + cP + " (5h) · click for details, right-click to refresh"
    }
    active: root.isUrgent

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
        source: Qt.resolvedUrl((service.usageData && service.usageData.activeCategory === "claude_others") ? "assets/claude.svg" : "assets/gemini.svg")
        sourceSize.width: Style.bar.iconCanvas
        sourceSize.height: Style.bar.iconCanvas
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showLabel && !root.vertical
        text: Model.formatPercent((service.usageData && service.usageData.session) ? service.usageData.session.percent : 0)
        color: root.isUrgent ? root.urgent : root.foreground
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
