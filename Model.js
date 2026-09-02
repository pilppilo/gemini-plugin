// Model.js — Formatting, pace calculation, and helpers for Gemini Usage

.pragma library

function formatPercent(value) {
  if (value === undefined || value === null || isNaN(value)) return "0%"
  return Math.round(Number(value) * 100) + "%"
}

function formatCompactNumber(value) {
  var num = Number(value || 0)
  if (isNaN(num)) return "0"
  if (num >= 1000000) return (num / 1000000).toFixed(1) + "M"
  if (num >= 1000) return (num / 1000).toFixed(1) + "k"
  return String(num)
}

function formatNumber(value) {
  var num = Number(value || 0)
  if (isNaN(num)) return "0"
  return num.toLocaleString()
}

function formatCountdown(seconds) {
  var sec = Math.max(0, parseInt(seconds || 0, 10))
  if (isNaN(sec) || sec <= 0) return "resets now"
  var days = Math.floor(sec / 86400)
  var hours = Math.floor((sec % 86400) / 3600)
  var minutes = Math.floor((sec % 3600) / 60)

  if (days > 0) return days + "d " + hours + "h"
  if (hours > 0) return hours + "h " + (minutes > 0 ? minutes + "m" : "")
  return Math.max(1, minutes) + "m"
}

function formatResetDate(isoString) {
  if (!isoString) return ""
  try {
    var d = new Date(isoString)
    if (isNaN(d.getTime())) return ""
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  } catch (e) {
    return ""
  }
}

function dayLabel(dateStr) {
  if (!dateStr) return ""
  try {
    var parts = dateStr.split("-")
    if (parts.length === 3) {
      var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
      var today = new Date()
      if (d.toDateString() === today.toDateString()) return "Today"
      var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
      return days[d.getDay()]
    }
  } catch (e) {}
  return dateStr.slice(-5)
}

function maxCount(days) {
  var max = 1
  if (!days || !days.length) return max
  for (var i = 0; i < days.length; i++) {
    var c = Number(days[i].messageCount || 0)
    if (c > max) max = c
  }
  return max
}
