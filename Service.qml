import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var usageData: ({
    id: "gemini",
    name: "Gemini",
    displayName: "Google Gemini",
    agentName: "Antigravity",
    account: "Loading…",
    model: "Gemini 3.8 Flash",
    tier: "Gemini Code Assist",
    ready: false,
    todayPrompts: 0,
    todaySessions: 0,
    todayTotalTokens: 0,
    totalPrompts: 0,
    totalSessions: 0,
    activeDays: 0,
    activeDates: [],
    behindPace: false,
    session: { used: 0, allowance: 50, percent: 0.0, resetsAt: "", resetRemainingSeconds: 0 },
    weekly: { used: 0, allowance: 500, percent: 0.0, resetsAt: "", resetRemainingSeconds: 0, behindPace: false },
    recentDays: [],
    recentSessions: [],
    updatedAt: "",
    statusText: ""
  })

  property bool refreshing: false
  property string lastError: ""
  property date lastUpdated: new Date(0)

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property int refreshIntervalSec: {
    var v = parseInt(settings ? settings.refreshIntervalSec : 300, 10)
    return isNaN(v) ? 300 : Math.max(30, Math.min(3600, v))
  }
  readonly property int sessionAllowance: {
    var v = parseInt(settings ? settings.sessionAllowance : 50, 10)
    return isNaN(v) ? 50 : Math.max(10, v)
  }
  readonly property int weeklyAllowance: {
    var v = parseInt(settings ? settings.weeklyAllowance : 500, 10)
    return isNaN(v) ? 500 : Math.max(50, v)
  }

  function refresh() {
    if (refreshing || collectorProcess.running) return
    refreshing = true
    lastError = ""
    var cmd = ["python3", root.pluginDir + "/collector.py"]
    cmd.push("--session-allowance", String(root.sessionAllowance))
    cmd.push("--weekly-allowance", String(root.weeklyAllowance))
    collectorProcess.command = cmd
    collectorProcess.running = true
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: collectorProcess
    running: false
    command: []

    stdout: StdioCollector {
      id: stdoutCollector
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: stderrCollector
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.refreshing = false
      var outText = String(stdoutCollector.text || "").trim()
      var errText = String(stderrCollector.text || "").trim()

      if (exitCode !== 0) {
        root.lastError = errText || "Collector exited with code " + exitCode
        console.warn("gemini-usage collector error:", root.lastError)
        return
      }

      if (outText.length > 0) {
        try {
          var parsed = JSON.parse(outText)
          root.usageData = parsed
          root.lastUpdated = new Date()
        } catch (e) {
          root.lastError = "Failed to parse collector JSON: " + e.message
          console.warn("gemini-usage JSON parse error:", e)
        }
      }
    }
  }
}
