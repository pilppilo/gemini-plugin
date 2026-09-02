import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "gemini-usage"
  ipcTarget: "gemini-usage"
  manageIpc: false

  property Item anchorItem: null
  property var service: null
  readonly property var usage: (service && service.usageData) ? service.usageData : ({})
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color cardBg: Color.popups.background
  readonly property color trackBg: Style.selectedFillFor(foreground, accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (service) service.refresh()
  }

  KeyboardPanel {
    id: keyboardPanel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: keyboardPanel.fittedContentWidth(Style.space(420))
    contentHeight: keyboardPanel.fittedContentHeight(panelContent.implicitHeight + Style.space(24), Style.space(660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.refresh()
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
      }

      Column {
        id: panelContent
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(14)
        topPadding: Style.space(12)
        bottomPadding: Style.space(12)

        // ------------------ Header / Hero Card ------------------
        RowLayout {
          width: parent.width

          RowLayout {
            spacing: Style.space(10)
            Layout.alignment: Qt.AlignVCenter

            Image {
              source: Qt.resolvedUrl("assets/gemini.svg")
              sourceSize.width: Style.space(28)
              sourceSize.height: Style.space(28)
            }

            ColumnLayout {
              spacing: Style.space(1)
              Text {
                text: "Gemini"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: (root.usage.tier || "GEMINI CODE ASSIST").toUpperCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 0.8
                font.bold: true
              }
            }
          }

          Item {
            Layout.fillWidth: true
          }

          Text {
            text: (service && service.refreshing) ? "Refreshing…" : "R to refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // ------------------ Limits & Rate Meters ------------------
        Text {
          text: "RATE LIMITS & ALLOWANCES"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        // 5-hour Session Window
        ColumnLayout {
          width: parent.width
          spacing: Style.space(6)

          RowLayout {
            width: parent.width
            Text {
              text: "5-Hour Session Window"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
              text: (root.usage.session ? root.usage.session.used : 0) + " / " + (root.usage.session ? root.usage.session.allowance : 50) + " prompts"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: Model.formatPercent(root.usage.session ? root.usage.session.percent : 0)
              color: (root.usage.session && root.usage.session.percent >= 0.85) ? root.urgent : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: Style.space(8)
            radius: Style.space(4)
            color: root.trackBg

            Rectangle {
              height: parent.height
              radius: parent.radius
              width: Math.max(0, Math.min(parent.width, parent.width * (root.usage.session ? root.usage.session.percent : 0)))
              color: (root.usage.session && root.usage.session.percent >= 0.85) ? root.urgent : root.accent
            }
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Resets in " + Model.formatCountdown((root.usage.session) ? root.usage.session.resetRemainingSeconds : 0)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "Rolling 5-hour window"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // 7-day Weekly Window
        ColumnLayout {
          width: parent.width
          spacing: Style.space(6)

          RowLayout {
            width: parent.width
            Text {
              text: "Weekly Allowance (7-day)"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
              text: (root.usage.weekly ? root.usage.weekly.used : 0) + " / " + (root.usage.weekly ? root.usage.weekly.allowance : 500) + " prompts"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: Model.formatPercent(root.usage.weekly ? root.usage.weekly.percent : 0)
              color: (root.usage.behindPace || (root.usage.weekly && root.usage.weekly.percent >= 0.85)) ? root.urgent : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: Style.space(8)
            radius: Style.space(4)
            color: root.trackBg

            Rectangle {
              height: parent.height
              radius: parent.radius
              width: Math.max(0, Math.min(parent.width, parent.width * (root.usage.weekly ? root.usage.weekly.percent : 0)))
              color: (root.usage.behindPace || (root.usage.weekly && root.usage.weekly.percent >= 0.85)) ? root.urgent : root.accent
            }
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Resets in " + Model.formatCountdown((root.usage.weekly) ? root.usage.weekly.resetRemainingSeconds : 0)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.usage.behindPace ? "Behind pace" : "On pace"
              color: root.usage.behindPace ? root.urgent : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // ------------------ 7-Day Chart ------------------
        RowLayout {
          width: parent.width
          Text {
            text: "PROMPTS LAST 7 DAYS"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "Today: " + (root.usage.todayPrompts || 0) + " prompts (" + Model.formatCompactNumber(root.usage.todayTotalTokens || 0) + " tokens)"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Row {
          id: chartRow
          width: parent.width
          spacing: Style.space(6)
          readonly property real colWidth: Math.floor((width - (spacing * 6)) / 7)
          readonly property real chartMax: Math.max(1, Model.maxCount(root.usage.recentDays))

          Repeater {
            model: root.usage.recentDays || []
            delegate: Column {
              width: chartRow.colWidth
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Number(modelData.messageCount || 0) > 0 ? String(modelData.messageCount) : ""
                color: (index === 6) ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: (index === 6)
              }

              Rectangle {
                width: parent.width
                height: Style.space(56)
                color: root.trackBg
                radius: Style.space(4)

                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: Number(modelData.messageCount || 0) > 0
                    ? Math.max(Style.space(4), Math.round(parent.height * (Number(modelData.messageCount || 0) / chartRow.chartMax)))
                    : 0
                  radius: parent.radius
                  color: (index === 6) ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                  visible: Number(modelData.messageCount || 0) > 0
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Model.dayLabel(modelData.date)
                color: (index === 6) ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: (index === 6)
              }
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // ------------------ Tokens by Model (matching upstream) ------------------
        Text {
          text: "TOKENS BY MODEL"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Repeater {
          model: (root.usage && root.usage.modelUsageList && root.usage.modelUsageList.length > 0)
            ? root.usage.modelUsageList
            : [{ name: root.usage.model || "Gemini 3.8 Flash", tokens: root.usage.todayTotalTokens || 0 }]
          delegate: Rectangle {
            width: parent.width
            height: Style.space(28)
            color: Style.selectedFillFor(root.foreground, root.accent)
            radius: Style.space(4)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)

              Text {
                text: modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              Text {
                text: Model.formatCompactNumber(modelData.tokens) + " tokens"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // ------------------ Recent Finished Job ------------------
        RowLayout {
          width: parent.width
          visible: Boolean(root.usage && root.usage.recentJob && root.usage.recentJob.title)
          spacing: Style.space(6)

          Text {
            text: "RECENT FINISHED JOB"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          // Status Badge
          Rectangle {
            implicitHeight: Style.space(16)
            implicitWidth: statusText.implicitWidth + Style.space(12)
            color: Style.selectedFillFor(root.foreground, root.accent)
            radius: Style.space(8)

            Text {
              id: statusText
              anchors.centerIn: parent
              text: "✓ " + (root.usage && root.usage.recentJob ? root.usage.recentJob.status : "Completed")
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
            }
          }

          Text {
            text: root.usage && root.usage.recentJob ? root.usage.recentJob.timeAgo : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
          }
        }

        Rectangle {
          width: parent.width
          visible: Boolean(root.usage && root.usage.recentJob && root.usage.recentJob.title)
          implicitHeight: jobCol.implicitHeight + Style.space(12)
          color: Style.selectedFillFor(root.foreground, root.accent)
          opacity: 0.85
          radius: Style.space(6)

          ColumnLayout {
            id: jobCol
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(5)

            // Prompt Title
            Text {
              text: root.usage && root.usage.recentJob ? root.usage.recentJob.title : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            // Summary / Result preview
            Text {
              text: root.usage && root.usage.recentJob && root.usage.recentJob.summary ? ("“" + root.usage.recentJob.summary + "”") : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.italic: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              Layout.fillWidth: true
              visible: Boolean(text.length > 0)
            }

            // Bottom metadata row: Workspace pill & steps/tools
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              Text {
                text: "📁 " + (root.usage && root.usage.recentJob ? root.usage.recentJob.workspace : "~")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                elide: Text.ElideMiddle
                Layout.fillWidth: true
              }

              Text {
                text: root.usage && root.usage.recentJob ? (root.usage.recentJob.steps + " steps · " + root.usage.recentJob.toolCalls + " tools") : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
              }
            }
          }
        }

        // ------------------ Footer / Status ------------------
        RowLayout {
          width: parent.width
          Text {
            text: root.usage.statusText || ("Active · " + (root.usage.totalPrompts || 0) + " total prompts")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "[R] Refresh · [Esc] Close"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
