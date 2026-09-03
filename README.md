# Gemini & Antigravity Usage for Omarchy

An Omarchy bar widget and details panel for **Google Gemini** and **Antigravity CLI (`agy`)**. Tracks 5-hour session allowances, weekly pace, prompt history, and recent sessions directly from your Omarchy bar.

![Gemini Usage preview](preview.png)

## What it shows

### In the Omarchy Bar
- **Gemini Sparkle Mark**: Native branding in the status bar.
- **Session Allowance & Pace**: Current rolling window usage percentage and time until next reset (e.g. `Gemini 28% · 1h 54m`).
- **Urgent / Behind Pace Indicator**: Turns warning/urgent color when quota consumption is tracking ahead of expected time pace or nearing limits (>85%).

### In the Details Panel (Left Click)
- **Hero Card**: Gemini / Antigravity mark, active model (e.g. `Gemini 3.8 Flash (Medium)`), **live subscription tier** (e.g. `Google AI Pro`, `Gemini Code Assist`, `Standard Tier`), and status.
- **5-Hour Rolling Session Meter**: Visual gauge, prompt count, remaining allowance, and live server countdown to window reset.
- **7-Day Weekly Meter & Pace**: Visual gauge, weekly allowance, live server reset timer, and pace status (`On pace` vs `Behind pace`).
- **7-Day Prompt History**: Responsive vertical bar chart tracking daily activity across the last 7 days, scaling automatically to your busiest day.
- **Recent Sessions**: Active Antigravity project workspaces, prompt counts, and conversation titles.

### Live Authoritative Quota & Tier Detection
The collector automatically discovers Antigravity's local Language Server and queries `RetrieveUserQuotaSummary` and `GetLoadCodeAssist`. This dynamically extracts real-time rate limits, exact reset timestamps, and your exact subscription tier (such as `Google AI Pro`) directly from server responses without requiring manual API keys or hardcoded allowances. If Antigravity is not running or is offline, it seamlessly falls back to cached stats and local activity scanning (`history.jsonl`).

### Built-in `omarchy.agents` Integration
Every refresh automatically syncs an authoritative `gemini.json` record into `~/.local/state/omarchy/agents/usage/`. If you also use Omarchy's built-in `omarchy.agents` panel, a **Gemini** tab will automatically appear alongside Claude and Codex!

---

## Installation

### From GitHub (Marketplace)
```bash
omarchy plugin add https://github.com/pilppilo/gemini-plugin.git --enable
```

### Local Checkout (Development)
```bash
omarchy plugin add ~/gemeni-plug --enable
```

---

## Controls & Keybindings

- **Left-click bar widget**: Open or close the details panel.
- **Right-click or Middle-click bar widget**: Force an immediate refresh.
- **Press `R`** while panel is open: Refresh stats.
- **Press `Esc`**: Close panel.
- **IPC Support**:
  ```bash
  omarchy-shell pilppilo.gemini-usage open
  omarchy-shell pilppilo.gemini-usage close
  omarchy-shell pilppilo.gemini-usage toggle
  omarchy-shell pilppilo.gemini-usage refresh
  omarchy-shell pilppilo.gemini-usage status
  ```

---

## Configuration

Settings can be customized directly or via `omarchy bar set`:

```bash
# Set refresh interval (in seconds, default: 300)
omarchy bar set pilppilo.gemini-usage refreshIntervalSec 180 --json

# Set rolling 5-hour session prompt allowance (default: 50)
omarchy bar set pilppilo.gemini-usage sessionAllowance 60 --json

# Set weekly prompt allowance (default: 500)
omarchy bar set pilppilo.gemini-usage weeklyAllowance 600 --json
```

---

## Requirements

- **Omarchy Quattro** with Quickshell plugin support.
- **Python 3** (included in Arch / Omarchy).
- Authenticated **Antigravity (`agy`)** or **Gemini CLI** on the machine.

---

## Removal

To remove the plugin from Omarchy:

```bash
omarchy plugin remove pilppilo.gemini-usage
```

---

## License

MIT © pilppilo
