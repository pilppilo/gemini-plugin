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
  property string selectedCategory: (root.usage && root.usage.activeCategory) ? root.usage.activeCategory : "gemini"

  readonly property var currentCategoryData: {
    if (root.usage && root.usage.categories) {
      if (root.usage.categories[root.selectedCategory]) {
        return root.usage.categories[root.selectedCategory]
      }
      if (root.usage.categories["gemini"]) {
        return root.usage.categories["gemini"]
      }
    }
    return ({})
  }

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

  onOpenedChanged: {
    if (root.opened && root.usage && root.usage.activeCategory) {
      root.selectedCategory = root.usage.activeCategory
    }
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
        else if (text === "1") root.selectedCategory = "gemini"
        else if (text === "2") root.selectedCategory = "claude_others"
      }

      Column {
        id: panelContent
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(12)
        topPadding: Style.space(12)
        bottomPadding: Style.space(12)

        // ------------------ Header / Hero Card ------------------
        RowLayout {
          width: parent.width

          RowLayout {
            spacing: Style.space(10)
            Layout.alignment: Qt.AlignVCenter

            Image {
              source: Qt.resolvedUrl(root.currentCategoryData.icon || (root.selectedCategory === "claude_others" ? "assets/claude.svg" : "assets/gemini.svg"))
              sourceSize.width: Style.space(28)
              sourceSize.height: Style.space(28)
            }

            ColumnLayout {
              spacing: Style.space(1)
              Text {
                text: root.currentCategoryData.displayName || (root.selectedCategory === "claude_others" ? "Claude / Others" : "Google Gemini")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: ((root.currentCategoryData.activeModel || root.usage.model || "GEMINI CODE ASSIST") + " · " + (root.usage.tier || "ANTIGRAVITY")).toUpperCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 0.8
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Style.space(240)
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

        // ------------------ 2-Category Switcher ------------------
        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            Layout.fillWidth: true
            height: Style.space(32)
            radius: Style.space(6)
            color: root.selectedCategory === "gemini" ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
            border.color: root.selectedCategory === "gemini" ? root.accent : Style.selectedFillFor(root.foreground, root.accent)
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedCategory = "gemini"
            }

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Image {
                source: Qt.resolvedUrl("assets/gemini.svg")
                sourceSize.width: Style.space(15)
                sourceSize.height: Style.space(15)
              }
              Text {
                text: "Gemini"
                color: root.selectedCategory === "gemini" ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body - 1
                font.bold: true
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: Style.space(32)
            radius: Style.space(6)
            color: root.selectedCategory === "claude_others" ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
            border.color: root.selectedCategory === "claude_others" ? root.accent : Style.selectedFillFor(root.foreground, root.accent)
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedCategory = "claude_others"
            }

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Image {
                source: Qt.resolvedUrl("assets/claude.svg")
                sourceSize.width: Style.space(15)
                sourceSize.height: Style.space(15)
              }
              Text {
                text: "Claude / Others"
                color: root.selectedCategory === "claude_others" ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body - 1
                font.bold: true
              }
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // ------------------ Limits & Rate Meters ------------------
        Text {
          text: "RATE LIMITS & ALLOWANCES (" + (root.currentCategoryData.name || "ACTIVE").toUpperCase() + ")"
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
              text: (root.currentCategoryData.session ? root.currentCategoryData.session.used : 0) + " / " + (root.currentCategoryData.session ? root.currentCategoryData.session.allowance : 50) + " prompts"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: Model.formatPercent(root.currentCategoryData.session ? root.currentCategoryData.session.percent : 0)
              color: (root.currentCategoryData.session && root.currentCategoryData.session.percent >= 0.85) ? root.urgent : root.accent
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
              width: Math.max(0, Math.min(parent.width, parent.width * (root.currentCategoryData.session ? root.currentCategoryData.session.percent : 0)))
              color: (root.currentCategoryData.session && root.currentCategoryData.session.percent >= 0.85) ? root.urgent : root.accent
            }
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Resets in " + Model.formatCountdown((root.currentCategoryData.session) ? root.currentCategoryData.session.resetRemainingSeconds : 0)
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
              text: (root.currentCategoryData.weekly ? root.currentCategoryData.weekly.used : 0) + " / " + (root.currentCategoryData.weekly ? root.currentCategoryData.weekly.allowance : 500) + " prompts"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: Model.formatPercent(root.currentCategoryData.weekly ? root.currentCategoryData.weekly.percent : 0)
              color: (root.currentCategoryData.behindPace || (root.currentCategoryData.weekly && root.currentCategoryData.weekly.percent >= 0.85)) ? root.urgent : root.accent
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
              width: Math.max(0, Math.min(parent.width, parent.width * (root.currentCategoryData.weekly ? root.currentCategoryData.weekly.percent : 0)))
              color: (root.currentCategoryData.behindPace || (root.currentCategoryData.weekly && root.currentCategoryData.weekly.percent >= 0.85)) ? root.urgent : root.accent
            }
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Resets in " + Model.formatCountdown((root.currentCategoryData.weekly) ? root.currentCategoryData.weekly.resetRemainingSeconds : 0)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.currentCategoryData.behindPace ? "Behind pace" : "On pace"
              color: root.currentCategoryData.behindPace ? root.urgent : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // ------------------ Tokens by Model ------------------
        RowLayout {
          width: parent.width
          Text {
            text: "TOKENS BY MODEL"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "Today: " + (root.currentCategoryData.todayPrompts || 0) + " prompts (" + Model.formatCompactNumber(root.currentCategoryData.todayTotalTokens || 0) + " tokens)"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Repeater {
          model: (root.currentCategoryData && root.currentCategoryData.modelUsageList && root.currentCategoryData.modelUsageList.length > 0)
            ? root.currentCategoryData.modelUsageList
            : [{ name: root.currentCategoryData.activeModel || "None", tokens: root.currentCategoryData.todayTotalTokens || 0 }]
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
            text: root.usage.statusText || ("Active · " + (root.currentCategoryData.totalPrompts || 0) + " prompts (" + (root.currentCategoryData.name || "Total") + ")")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "[1] Gemini · [2] Claude · [R] Refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
