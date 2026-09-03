#!/usr/bin/env python3
"""
Gemini & Antigravity Usage Collector for Omarchy.
Extracts live authoritative quota and subscription tier from Antigravity's local language server,
with automatic fallback to local history and cached states.
Outputs JSON for the Omarchy Bar Widget & Panel and syncs ~/.local/state/omarchy/agents/usage/gemini.json.
"""

import argparse
import json
import os
import re
import socket
import sqlite3
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_SESSION_ALLOWANCE = 50
DEFAULT_WEEKLY_ALLOWANCE = 500


def get_paths():
    home = Path.home()
    return {
        "gemini_dir": home / ".gemini",
        "antigravity_cli": home / ".gemini" / "antigravity-cli",
        "history_file": home / ".gemini" / "antigravity-cli" / "history.jsonl",
        "db_file": home / ".gemini" / "antigravity-cli" / "conversation_summaries.db",
        "settings_file": home / ".gemini" / "antigravity-cli" / "settings.json",
        "oauth_creds": home / ".gemini" / "oauth_creds.json",
        "antigravity_token": home / ".gemini" / "antigravity-cli" / "antigravity-oauth-token",
        "cache_file": home / ".cache" / "omarchy" / "antigravity-live-quota.json",
        "state_dir": Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state"))) / "omarchy" / "agents" / "usage"
    }


def find_cli_log(antigravity_cli_dir):
    cli_log = antigravity_cli_dir / "cli.log"
    if cli_log.exists():
        return cli_log
    log_dir = antigravity_cli_dir / "log"
    if log_dir.exists():
        try:
            logs = sorted(log_dir.glob("cli-*.log"), key=os.path.getmtime, reverse=True)
            if logs:
                return logs[0]
        except Exception:
            pass
    return None


def find_language_server_port(antigravity_cli_dir):
    log_file = find_cli_log(antigravity_cli_dir)
    if not log_file or not log_file.exists():
        return None
    try:
        candidates = []
        with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                m = re.search(r"listening on random port at (\d+) for HTTP\b", line)
                if m:
                    candidates.append(int(m.group(1)))

        for candidate in reversed(candidates):
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(0.2)
                if s.connect_ex(("127.0.0.1", candidate)) == 0:
                    s.close()
                    return candidate
                s.close()
            except Exception:
                pass
    except Exception:
        pass
    return None


def fetch_live_quota(port):
    if not port:
        return None, None
    quota_data = None
    tier_data = None
    try:
        url_q = f"http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
        req_q = urllib.request.Request(url_q, headers={"Content-Type": "application/json"}, data=b"{}")
        with urllib.request.urlopen(req_q, timeout=2) as resp:
            quota_data = json.loads(resp.read().decode())
    except Exception:
        pass

    try:
        url_t = f"http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetLoadCodeAssist"
        req_t = urllib.request.Request(url_t, headers={"Content-Type": "application/json"}, data=b"{}")
        with urllib.request.urlopen(req_t, timeout=2) as resp:
            tier_data = json.loads(resp.read().decode())
    except Exception:
        pass

    return quota_data, tier_data


def parse_live_data(quota_data, tier_data):
    if not quota_data:
        return None

    tier_label = "Google AI Pro"
    if tier_data:
        t_resp = tier_data.get("response", {})
        paid = t_resp.get("paidTier", {})
        current = t_resp.get("currentTier", {})
        if paid.get("name"):
            tier_label = paid.get("name")
        elif current.get("name"):
            tier_label = current.get("name")

    session_info = None
    weekly_info = None

    groups = quota_data.get("response", {}).get("groups", [])
    now_ts = time.time()

    for g in groups:
        if "gemini" in g.get("displayName", "").lower() or "gemini" in g.get("description", "").lower():
            for b in g.get("buckets", []):
                window = b.get("window")
                rem_frac = b.get("remainingFraction", 1.0)
                used_pct = max(0.0, min(1.0, round(1.0 - rem_frac, 4)))
                reset_time = b.get("resetTime", "")

                rem_sec = 0
                if reset_time:
                    try:
                        clean_reset = reset_time.replace("Z", "+00:00")
                        dt_reset = datetime.fromisoformat(clean_reset)
                        rem_sec = max(0, int(dt_reset.timestamp() - now_ts))
                    except Exception:
                        pass

                if window == "5h":
                    session_info = {
                        "percent": used_pct,
                        "resetsAt": reset_time,
                        "resetRemainingSeconds": rem_sec
                    }
                elif window == "weekly":
                    weekly_info = {
                        "percent": used_pct,
                        "resetsAt": reset_time,
                        "resetRemainingSeconds": rem_sec
                    }

    if not session_info and not weekly_info:
        return None

    return {
        "tier_label": tier_label,
        "session": session_info,
        "weekly": weekly_info
    }


def parse_history(history_file, session_allowance, weekly_allowance):
    now = datetime.now()
    now_ts_ms = time.time() * 1000
    five_hours_ms = 5 * 3600 * 1000
    seven_days_ms = 7 * 24 * 3600 * 1000

    cutoff_5h = now_ts_ms - five_hours_ms
    cutoff_7d = now_ts_ms - seven_days_ms

    today_str = now.strftime("%Y-%m-%d")
    recent_dates = [(now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]
    recent_day_map = {d: 0 for d in recent_dates}

    active_dates = set()
    today_sessions = set()
    total_sessions = set()

    total_prompts = 0
    today_prompts = 0
    session_prompts = 0
    weekly_prompts = 0

    oldest_in_5h = None
    oldest_in_7d = None

    if history_file.exists():
        try:
            with open(history_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        total_prompts += 1
                        cid = entry.get("conversationId")
                        if cid:
                            total_sessions.add(cid)

                        ts = entry.get("timestamp", 0)
                        if ts <= 0:
                            continue

                        # Check 5h window
                        if ts >= cutoff_5h:
                            session_prompts += 1
                            if oldest_in_5h is None or ts < oldest_in_5h:
                                oldest_in_5h = ts

                        # Check 7d window
                        if ts >= cutoff_7d:
                            weekly_prompts += 1
                            if oldest_in_7d is None or ts < oldest_in_7d:
                                oldest_in_7d = ts

                        dt = datetime.fromtimestamp(ts / 1000.0) if ts > 1e11 else datetime.fromtimestamp(ts)
                        day_str = dt.strftime("%Y-%m-%d")
                        active_dates.add(day_str)

                        if day_str in recent_day_map:
                            recent_day_map[day_str] += 1

                        if day_str == today_str:
                            today_prompts += 1
                            if cid:
                                today_sessions.add(cid)
                    except Exception:
                        pass
        except Exception as e:
            sys.stderr.write(f"Warning: could not read history: {e}\n")

    # Resets calculation
    if oldest_in_5h:
        reset_5h_ts = (oldest_in_5h + five_hours_ms) / 1000.0
    else:
        reset_5h_ts = time.time() + (5 * 3600)

    if oldest_in_7d:
        reset_7d_ts = (oldest_in_7d + seven_days_ms) / 1000.0
    else:
        reset_7d_ts = time.time() + (7 * 24 * 3600)

    reset_5h_dt = datetime.fromtimestamp(reset_5h_ts, tz=timezone.utc)
    reset_7d_dt = datetime.fromtimestamp(reset_7d_ts, tz=timezone.utc)

    session_percent = min(1.0, round(session_prompts / float(max(1, session_allowance)), 4))
    weekly_percent = min(1.0, round(weekly_prompts / float(max(1, weekly_allowance)), 4))

    if oldest_in_7d:
        elapsed_week_ratio = min(1.0, (now_ts_ms - oldest_in_7d) / float(seven_days_ms))
    else:
        elapsed_week_ratio = 0.5
    behind_pace = (weekly_percent > (elapsed_week_ratio + 0.15)) and (weekly_prompts > 10)

    recent_days = [{"date": d, "messageCount": recent_day_map[d]} for d in recent_dates]

    return {
        "total_prompts": total_prompts,
        "today_prompts": today_prompts,
        "today_sessions": len(today_sessions),
        "total_sessions": len(total_sessions),
        "session_prompts": session_prompts,
        "weekly_prompts": weekly_prompts,
        "session_percent": session_percent,
        "weekly_percent": weekly_percent,
        "reset_5h_iso": reset_5h_dt.isoformat(),
        "reset_7d_iso": reset_7d_dt.isoformat(),
        "reset_5h_seconds": max(0, int(reset_5h_ts - time.time())),
        "reset_7d_seconds": max(0, int(reset_7d_ts - time.time())),
        "behind_pace": behind_pace,
        "recent_days": recent_days,
        "active_days": len(active_dates),
        "active_dates": sorted(list(active_dates))
    }


def sanitize_path(path_str):
    if not path_str:
        return ""
    p = path_str.replace("file://", "")
    return re.sub(r"^/home/[^/]+", "~", p)


def parse_sessions_db(db_file):
    sessions = []
    if not db_file.exists():
        return sessions

    try:
        conn = sqlite3.connect(f"file:{db_file}?mode=ro", uri=True)
        c = conn.cursor()
        for row in c.execute(
            "SELECT conversation_id, title, step_count, last_modified_time, workspace_uris "
            "FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 6"
        ):
            cid, title, steps, mtime, uris = row
            ws = ""
            try:
                u = json.loads(uris)
                if u and isinstance(u, list):
                    ws = sanitize_path(u[0])
            except Exception:
                ws = sanitize_path(str(uris or ""))

            sessions.append({
                "id": str(cid or "")[:8],
                "fullId": str(cid or ""),
                "title": (title or "Session").strip(),
                "steps": steps or 0,
                "modified": str(mtime or "")[:19].replace("T", " "),
                "workspace": ws
            })
        conn.close()
    except Exception as e:
        sys.stderr.write(f"Warning: could not query conversation_summaries.db: {e}\n")

    return sessions


def get_model_and_tier(paths):
    tier_label = "Google AI Pro"
    model_name = "Gemini 3.8 Flash (Medium)"
    ready = False

    if paths["antigravity_token"].exists() or paths["oauth_creds"].exists():
        ready = True

    if paths["settings_file"].exists():
        try:
            with open(paths["settings_file"], "r", encoding="utf-8") as f:
                data = json.load(f)
                m = data.get("model")
                if m:
                    model_name = m
        except Exception:
            pass

    return {
        "tier_label": tier_label,
        "model_name": model_name,
        "ready": ready
    }


def publish_omarchy_state(paths, payload):
    try:
        paths["state_dir"].mkdir(parents=True, exist_ok=True)
        gemini_state = {
            "schemaVersion": 1,
            "id": "gemini",
            "name": "Gemini",
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "ready": payload["ready"],
            "hasLocalStats": True,
            "todayPrompts": payload["todayPrompts"],
            "todaySessions": payload["todaySessions"],
            "todayTotalTokens": payload["todayTotalTokens"],
            "todayTokensByModel": {
                payload["model"]: payload["todayTotalTokens"]
            },
            "recentDays": payload["recentDays"],
            "totalPrompts": payload["totalPrompts"],
            "totalSessions": payload["totalSessions"],
            "activeDays": payload["activeDays"],
            "activeDates": payload["activeDates"],
            "modelUsage": {
                payload["model"]: {
                    "inputTokens": int(payload["todayTotalTokens"] * 0.7),
                    "outputTokens": int(payload["todayTotalTokens"] * 0.3),
                    "cacheReadInputTokens": 0,
                    "cacheCreationInputTokens": 0
                }
            },
            "limits": [
                {
                    "label": "5h window",
                    "percent": payload["session"]["percent"],
                    "resetsAt": payload["session"]["resetsAt"]
                },
                {
                    "label": "Weekly (7-day)",
                    "percent": payload["weekly"]["percent"],
                    "resetsAt": payload["weekly"]["resetsAt"]
                }
            ],
            "tierLabel": payload["tier"],
            "usageStatusText": "" if payload["ready"] else "Waiting for auth",
            "authHelpText": "Run `agy` to authenticate."
        }

        tmp_path = paths["state_dir"] / ".gemini.tmp"
        final_path = paths["state_dir"] / "gemini.json"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(gemini_state, f, indent=2)
        tmp_path.replace(final_path)
    except Exception as e:
        sys.stderr.write(f"Warning: could not write omarchy state: {e}\n")


def main():
    parser = argparse.ArgumentParser(description="Collect Gemini & Antigravity usage stats for Omarchy")
    parser.add_argument("--session-allowance", type=int, default=DEFAULT_SESSION_ALLOWANCE, help="5-hour session prompt allowance")
    parser.add_argument("--weekly-allowance", type=int, default=DEFAULT_WEEKLY_ALLOWANCE, help="7-day prompt allowance")
    parser.add_argument("--limits-only", action="store_true", help="Fast output with limits only")
    parser.add_argument("--no-sync", action="store_true", help="Do not write to ~/.local/state/omarchy/agents/usage/gemini.json")
    args = parser.parse_args()

    paths = get_paths()
    meta = get_model_and_tier(paths)
    stats = parse_history(paths["history_file"], args.session_allowance, args.weekly_allowance)
    recent_sessions = parse_sessions_db(paths["db_file"]) if not args.limits_only else []

    # Attempt to query live authoritative data from local Antigravity Language Server
    live_quota = None
    port = find_language_server_port(paths["antigravity_cli"])
    if port:
        q_raw, t_raw = fetch_live_quota(port)
        if q_raw:
            live_quota = parse_live_data(q_raw, t_raw)
            if live_quota:
                try:
                    paths["cache_file"].parent.mkdir(parents=True, exist_ok=True)
                    with open(paths["cache_file"], "w", encoding="utf-8") as f:
                        json.dump(live_quota, f)
                except Exception:
                    pass

    # If live query failed, check cache
    if not live_quota and paths["cache_file"].exists():
        try:
            with open(paths["cache_file"], "r", encoding="utf-8") as f:
                live_quota = json.load(f)
        except Exception:
            pass

    # Merge live data when available
    session_used = stats["session_prompts"]
    session_allowance = args.session_allowance
    session_percent = stats["session_percent"]
    session_reset_iso = stats["reset_5h_iso"]
    session_reset_sec = stats["reset_5h_seconds"]

    weekly_used = stats["weekly_prompts"]
    weekly_allowance = args.weekly_allowance
    weekly_percent = stats["weekly_percent"]
    weekly_reset_iso = stats["reset_7d_iso"]
    weekly_reset_sec = stats["reset_7d_seconds"]

    if live_quota:
        if live_quota.get("tier_label"):
            meta["tier_label"] = live_quota["tier_label"]

        if live_quota.get("session"):
            s = live_quota["session"]
            session_percent = s["percent"]
            session_reset_iso = s["resetsAt"]
            session_reset_sec = s["resetRemainingSeconds"]
            if session_percent > 0:
                session_allowance = max(session_used, int(round(session_used / session_percent)))
            else:
                session_allowance = max(session_allowance, 100)

        if live_quota.get("weekly"):
            w = live_quota["weekly"]
            weekly_percent = w["percent"]
            weekly_reset_iso = w["resetsAt"]
            weekly_reset_sec = w["resetRemainingSeconds"]
            if weekly_percent > 0:
                weekly_allowance = max(weekly_used, int(round(weekly_used / weekly_percent)))
            else:
                weekly_allowance = max(weekly_allowance, 1500)

    today_tokens = stats["today_prompts"] * 2500
    total_tokens = stats["total_prompts"] * 2500

    result = {
        "id": "gemini",
        "name": "Gemini",
        "displayName": "Google Gemini",
        "agentName": "Antigravity",
        "model": meta["model_name"],
        "tier": meta["tier_label"],
        "ready": meta["ready"],
        "todayPrompts": stats["today_prompts"],
        "todaySessions": stats["today_sessions"],
        "todayTotalTokens": today_tokens,
        "totalPrompts": stats["total_prompts"],
        "totalSessions": stats["total_sessions"],
        "activeDays": stats["active_days"],
        "activeDates": stats["active_dates"],
        "behindPace": stats["behind_pace"],
        "session": {
            "used": session_used,
            "allowance": session_allowance,
            "percent": session_percent,
            "resetsAt": session_reset_iso,
            "resetRemainingSeconds": session_reset_sec
        },
        "weekly": {
            "used": weekly_used,
            "allowance": weekly_allowance,
            "percent": weekly_percent,
            "resetsAt": weekly_reset_iso,
            "resetRemainingSeconds": weekly_reset_sec,
            "behindPace": stats["behind_pace"]
        },
        "recentDays": stats["recent_days"],
        "modelUsageList": [{"name": meta["model_name"], "tokens": today_tokens}],
        "recentSessions": recent_sessions,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "statusText": "" if meta["ready"] else "Waiting for auth"
    }

    if not args.no_sync:
        publish_omarchy_state(paths, result)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
