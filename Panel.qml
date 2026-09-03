import QtQuick
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
    contentWidth: keyboardPanel.fittedContentWidth(Style.space(370))
    contentHeight: keyboardPanel.fittedContentHeight(Style.space(490), Style.space(490))

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

      Item {
        id: panelContent
        anchors.fill: parent
        anchors.margins: Style.space(6)

        // ------------------ 1. Header / Hero Row ------------------
        Item {
          id: headerRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(34)

          Row {
            anchors.left: parent.left
            anchors.right: refreshLabel.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Image {
              source: Qt.resolvedUrl(root.currentCategoryData.icon || (root.selectedCategory === "claude_others" ? "assets/claude.svg" : "assets/gemini.svg"))
              sourceSize.width: Style.space(24)
              sourceSize.height: Style.space(24)
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: root.currentCategoryData.displayName || (root.selectedCategory === "claude_others" ? "Claude / Others" : "Google Gemini")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: ((root.currentCategoryData.activeModel || root.usage.model || "GEMINI") + " · " + (root.usage.tier || "ANTIGRAVITY")).toUpperCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 0.8
                font.bold: true
                elide: Text.ElideRight
                width: Style.space(210)
              }
            }
          }

          Text {
            id: refreshLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (service && service.refreshing) ? "Refreshing…" : "R to refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // ------------------ 2. Switcher Pills ------------------
        Item {
          id: switcherRow
          anchors.top: headerRow.bottom
          anchors.topMargin: Style.space(10)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(30)

          Rectangle {
            anchors.left: parent.left
            width: (parent.width - Style.space(8)) / 2
            height: parent.height
            radius: Style.space(6)
            color: root.selectedCategory === "gemini" ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
            border.color: root.selectedCategory === "gemini" ? root.accent : Style.selectedFillFor(root.foreground, root.accent)
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedCategory = "gemini"
            }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Image {
                source: Qt.resolvedUrl("assets/gemini.svg")
                sourceSize.width: Style.space(13)
                sourceSize.height: Style.space(13)
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "Gemini"
                color: root.selectedCategory === "gemini" ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body - 1
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Rectangle {
            anchors.right: parent.right
            width: (parent.width - Style.space(8)) / 2
            height: parent.height
            radius: Style.space(6)
            color: root.selectedCategory === "claude_others" ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
            border.color: root.selectedCategory === "claude_others" ? root.accent : Style.selectedFillFor(root.foreground, root.accent)
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedCategory = "claude_others"
            }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Image {
                source: Qt.resolvedUrl("assets/claude.svg")
                sourceSize.width: Style.space(13)
                sourceSize.height: Style.space(13)
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "Claude / Others"
                color: root.selectedCategory === "claude_others" ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body - 1
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        // Top Content Separator
        PanelSeparator {
          id: topSeparator
          anchors.top: switcherRow.bottom
          anchors.topMargin: Style.space(10)
          anchors.left: parent.left
          anchors.right: parent.right
          foreground: root.foreground
        }

        // ------------------ 3. Rate Limits & Allowances ------------------
        Text {
          id: limitsTitle
          anchors.top: topSeparator.bottom
          anchors.topMargin: Style.space(10)
          anchors.left: parent.left
          text: "RATE LIMITS & ALLOWANCES (" + (root.currentCategoryData.name || "ACTIVE").toUpperCase() + ")"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        // 5-Hour Session Window
        Item {
          id: sessionMeter
          anchors.top: limitsTitle.bottom
          anchors.topMargin: Style.space(6)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(40)

          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(16)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "5-Hour Session Window"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

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
          }

          Rectangle {
            anchors.top: parent.top
            anchors.topMargin: Style.space(18)
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(7)
            radius: Style.space(4)
            color: root.trackBg

            Rectangle {
              height: parent.height
              radius: parent.radius
              width: Math.max(0, Math.min(parent.width, parent.width * (root.currentCategoryData.session ? root.currentCategoryData.session.percent : 0)))
              color: (root.currentCategoryData.session && root.currentCategoryData.session.percent >= 0.85) ? root.urgent : root.accent
            }
          }

          Item {
            anchors.top: parent.top
            anchors.topMargin: Style.space(28)
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(12)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Resets in " + Model.formatCountdown((root.currentCategoryData.session) ? root.currentCategoryData.session.resetRemainingSeconds : 0)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Rolling 5-hour window"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Weekly Allowance (7-Day)
        Item {
          id: weeklyMeter
          anchors.top: sessionMeter.bottom
          anchors.topMargin: Style.space(6)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(40)

          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(16)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Weekly Allowance (7-day)"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

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
          }

          Rectangle {
            anchors.top: parent.top
            anchors.topMargin: Style.space(18)
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(7)
            radius: Style.space(4)
            color: root.trackBg

            Rectangle {
              height: parent.height
              radius: parent.radius
              width: Math.max(0, Math.min(parent.width, parent.width * (root.currentCategoryData.weekly ? root.currentCategoryData.weekly.percent : 0)))
              color: (root.currentCategoryData.behindPace || (root.currentCategoryData.weekly && root.currentCategoryData.weekly.percent >= 0.85)) ? root.urgent : root.accent
            }
          }

          Item {
            anchors.top: parent.top
            anchors.topMargin: Style.space(28)
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(12)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Resets in " + Model.formatCountdown((root.currentCategoryData.weekly) ? root.currentCategoryData.weekly.resetRemainingSeconds : 0)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.currentCategoryData.behindPace ? "Behind pace" : "On pace"
              color: root.currentCategoryData.behindPace ? root.urgent : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        // Middle Separator
        PanelSeparator {
          id: midSeparator
          anchors.top: weeklyMeter.bottom
          anchors.topMargin: Style.space(8)
          anchors.left: parent.left
          anchors.right: parent.right
          foreground: root.foreground
        }

        // ------------------ 4. Tokens by Model ------------------
        Item {
          id: tokensHeaderRow
          anchors.top: midSeparator.bottom
          anchors.topMargin: Style.space(8)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(16)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "TOKENS BY MODEL"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "This Week: " + (root.currentCategoryData.weekly ? root.currentCategoryData.weekly.used : 0) + " prompts (" + Model.formatCompactNumber(root.currentCategoryData.weeklyTotalTokens || 0) + " tokens)"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Column {
          id: modelsColumn
          anchors.top: tokensHeaderRow.bottom
          anchors.topMargin: Style.space(5)
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(4)

          Repeater {
            model: (root.currentCategoryData && root.currentCategoryData.modelUsageList && root.currentCategoryData.modelUsageList.length > 0)
              ? root.currentCategoryData.modelUsageList
              : [{ name: root.currentCategoryData.activeModel || "None", tokens: root.currentCategoryData.todayTotalTokens || 0, prompts: root.currentCategoryData.todayPrompts || 0 }]

            delegate: Rectangle {
              width: modelsColumn.width
              height: Style.space(26)
              color: Style.selectedFillFor(root.foreground, root.accent)
              radius: Style.space(4)

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: statText.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Text {
                id: statText
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: (modelData.prompts ? (modelData.prompts + " prompts · ") : "") + Model.formatCompactNumber(modelData.tokens) + " tokens"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // ------------------ 5. Recent Finished Job ------------------
        Item {
          id: jobHeaderRow
          anchors.top: modelsColumn.bottom
          anchors.topMargin: Style.space(8)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(16)
          visible: Boolean(root.usage && root.usage.recentJob && root.usage.recentJob.title)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "RECENT FINISHED JOB"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Rectangle {
              height: Style.space(15)
              width: statusBadgeText.implicitWidth + Style.space(10)
              color: Style.selectedFillFor(root.foreground, root.accent)
              radius: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                id: statusBadgeText
                anchors.centerIn: parent
                text: "✓ " + (root.usage && root.usage.recentJob ? root.usage.recentJob.status : "Completed")
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.usage && root.usage.recentJob ? root.usage.recentJob.timeAgo : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
          }
        }

        Rectangle {
          id: jobCard
          anchors.top: jobHeaderRow.bottom
          anchors.topMargin: Style.space(5)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(48)
          color: Style.selectedFillFor(root.foreground, root.accent)
          radius: Style.space(6)
          visible: Boolean(root.usage && root.usage.recentJob && root.usage.recentJob.title)

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(7)
            spacing: Style.space(3)

            Text {
              width: parent.width
              text: root.usage && root.usage.recentJob ? root.usage.recentJob.title : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "📁 " + (root.usage && root.usage.recentJob ? root.usage.recentJob.workspace : "~")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
              }

              Item { width: Style.space(4); height: 1 }

              Text {
                text: root.usage && root.usage.recentJob ? (root.usage.recentJob.steps + " steps") : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
              }
            }
          }
        }

        // ------------------ 6. Bottom Footer / Status ------------------
        PanelSeparator {
          id: footerSeparator
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footerRow.top
          anchors.bottomMargin: Style.space(6)
          foreground: root.foreground
        }

        Item {
          id: footerRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(16)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.usage.statusText || ("Active · " + (root.currentCategoryData.totalPrompts || 0) + " prompts (" + (root.currentCategoryData.name || "Total") + ")")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
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
