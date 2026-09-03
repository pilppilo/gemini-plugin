#!/usr/bin/env python3
"""
Gemini & Antigravity Usage Collector for Omarchy.
Extracts usage statistics, rate limits, prompts, and pace for two categories:
  1) Gemini (Google Gemini models)
  2) Claude / Others (Claude Opus/Sonnet, GPT-OSS, and other third-party models)
Outputs JSON for the Omarchy Bar Widget & Details Panel.
Also synchronizes ~/.local/state/omarchy/agents/usage/gemini.json and claude.json.
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_SESSION_ALLOWANCE = 50
DEFAULT_WEEKLY_ALLOWANCE = 500
DEFAULT_CLAUDE_SESSION_ALLOWANCE = 50
DEFAULT_CLAUDE_WEEKLY_ALLOWANCE = 500


def get_paths():
    home = Path.home()
    return {
        "gemini_dir": home / ".gemini",
        "antigravity_cli": home / ".gemini" / "antigravity-cli",
        "history_file": home / ".gemini" / "antigravity-cli" / "history.jsonl",
        "settings_file": home / ".gemini" / "antigravity-cli" / "settings.json",
        "oauth_creds": home / ".gemini" / "oauth_creds.json",
        "antigravity_token": home / ".gemini" / "antigravity-cli" / "antigravity-oauth-token",
        "claude_dir": home / ".claude",
        "state_dir": Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state"))) / "omarchy" / "agents" / "usage"
    }


def canonical_model(name):
    if not name:
        return "Unknown"
    cleaned = re.sub(r"\s*\([^)]*\)", "", name).strip()
    return cleaned or name.strip()


def get_category(model_name):
    if not model_name:
        return "gemini"
    low = model_name.lower()
    if "gemini" in low:
        return "gemini"
    return "claude_others"


def build_conversation_timelines(paths):
    brain_dir = paths["antigravity_cli"] / "brain"
    cid_timelines = {}
    if not brain_dir.exists():
        return cid_timelines

    for d in brain_dir.iterdir():
        if not d.is_dir():
            continue
        cid = d.name
        t_file = d / ".system_generated" / "logs" / "transcript.jsonl"
        if not t_file.exists():
            continue
        intervals = []
        try:
            with open(t_file, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    if "Model Selection" in line:
                        m = re.search(r"Model Selection\` from .*? to (.*?)\.\s*No need", line)
                        if not m:
                            m = re.search(r"Model Selection\` from .*? to ([A-Za-z0-9\s\.\(\)\-]+?)(?:\.\s|\n|$)", line)
                        if m:
                            model_name = canonical_model(m.group(1).strip())
                            try:
                                step = json.loads(line)
                                created = step.get("created_at")
                                if created:
                                    dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
                                    intervals.append((dt.timestamp() * 1000, model_name))
                                else:
                                    intervals.append((0, model_name))
                            except Exception:
                                intervals.append((0, model_name))
        except Exception:
            pass

        intervals.sort(key=lambda x: x[0])
        if intervals:
            cid_timelines[cid] = intervals

    return cid_timelines


def resolve_model_at_ts(cid_timelines, cid, ts, default_model):
    intervals = cid_timelines.get(cid)
    if not intervals:
        return default_model
    current = intervals[0][1]
    for m_ts, m_name in intervals:
        if ts >= m_ts:
            current = m_name
        else:
            break
    return current


def init_category_bucket():
    return {
        "total_prompts": 0,
        "today_prompts": 0,
        "session_prompts": 0,
        "weekly_prompts": 0,
        "oldest_in_5h": None,
        "oldest_in_7d": None,
        "active_dates": set(),
        "recent_day_map": {},
        "weekly_model_tokens": {},
        "weekly_model_prompts": {},
        "today_model_tokens": {},
        "today_model_prompts": {},
        "models_seen": set()
    }


def parse_history_by_category(paths, allowances, default_model):
    now = datetime.now()
    now_ts = time.time()
    now_ts_ms = now_ts * 1000
    five_hours_ms = 5 * 3600 * 1000
    seven_days_ms = 7 * 24 * 3600 * 1000

    cutoff_5h = now_ts_ms - five_hours_ms
    cutoff_7d = now_ts_ms - seven_days_ms
    today_str = now.strftime("%Y-%m-%d")
    recent_dates = [(now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]

    cid_timelines = build_conversation_timelines(paths)
    canon_default = canonical_model(default_model)

    raw_buckets = {
        "gemini": init_category_bucket(),
        "claude_others": init_category_bucket()
    }
    for cat in raw_buckets:
        raw_buckets[cat]["recent_day_map"] = {d: 0 for d in recent_dates}

    history_file = paths["history_file"]
    if history_file.exists():
        try:
            with open(history_file, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        cid = entry.get("conversationId")
                        ts = entry.get("timestamp", 0)

                        model = resolve_model_at_ts(cid_timelines, cid, ts, canon_default)
                        model = canonical_model(model)
                        cat = get_category(model)
                        b = raw_buckets[cat]

                        b["total_prompts"] += 1
                        b["models_seen"].add(model)

                        if ts <= 0:
                            continue

                        # Check 5h window
                        if ts >= cutoff_5h:
                            b["session_prompts"] += 1
                            if b["oldest_in_5h"] is None or ts < b["oldest_in_5h"]:
                                b["oldest_in_5h"] = ts

                        # Check 7d window
                        if ts >= cutoff_7d:
                            b["weekly_prompts"] += 1
                            if b["oldest_in_7d"] is None or ts < b["oldest_in_7d"]:
                                b["oldest_in_7d"] = ts

                            # Accumulate weekly model tokens and prompt counts by model
                            b["weekly_model_prompts"][model] = b["weekly_model_prompts"].get(model, 0) + 1
                            b["weekly_model_tokens"][model] = b["weekly_model_tokens"].get(model, 0) + 2500

                        dt = datetime.fromtimestamp(ts / 1000.0) if ts > 1e11 else datetime.fromtimestamp(ts)
                        day_str = dt.strftime("%Y-%m-%d")
                        b["active_dates"].add(day_str)

                        if day_str in b["recent_day_map"]:
                            b["recent_day_map"][day_str] += 1

                        if day_str == today_str:
                            b["today_prompts"] += 1
                            b["today_model_prompts"][model] = b["today_model_prompts"].get(model, 0) + 1
                            b["today_model_tokens"][model] = b["today_model_tokens"].get(model, 0) + 2500
                    except Exception:
                        pass
        except Exception as e:
            sys.stderr.write(f"Warning: could not read history: {e}\n")

    # Optional scan of ~/.claude if present and non-empty
    claude_history = paths["claude_dir"] / "history.jsonl"
    if claude_history.exists():
        try:
            with open(claude_history, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        b = raw_buckets["claude_others"]
                        b["total_prompts"] += 1
                        b["models_seen"].add("Claude Code")
                        ts = entry.get("timestamp", 0)
                        if ts <= 0:
                            continue
                        if ts >= cutoff_5h:
                            b["session_prompts"] += 1
                            if b["oldest_in_5h"] is None or ts < b["oldest_in_5h"]:
                                b["oldest_in_5h"] = ts
                        if ts >= cutoff_7d:
                            b["weekly_prompts"] += 1
                            if b["oldest_in_7d"] is None or ts < b["oldest_in_7d"]:
                                b["oldest_in_7d"] = ts
                            b["weekly_model_prompts"]["Claude Code"] = b["weekly_model_prompts"].get("Claude Code", 0) + 1
                            b["weekly_model_tokens"]["Claude Code"] = b["weekly_model_tokens"].get("Claude Code", 0) + 2500
                        dt = datetime.fromtimestamp(ts / 1000.0) if ts > 1e11 else datetime.fromtimestamp(ts)
                        day_str = dt.strftime("%Y-%m-%d")
                        b["active_dates"].add(day_str)
                        if day_str in b["recent_day_map"]:
                            b["recent_day_map"][day_str] += 1
                        if day_str == today_str:
                            b["today_prompts"] += 1
                            b["today_model_prompts"]["Claude Code"] = b["today_model_prompts"].get("Claude Code", 0) + 1
                            b["today_model_tokens"]["Claude Code"] = b["today_model_tokens"].get("Claude Code", 0) + 2500
                    except Exception:
                        pass
        except Exception:
            pass

    categories = {}
    config_map = {
        "gemini": {
            "id": "gemini",
            "name": "Gemini",
            "displayName": "Google Gemini",
            "icon": "assets/gemini.svg",
            "session_allowance": allowances["gemini_session"],
            "weekly_allowance": allowances["gemini_weekly"]
        },
        "claude_others": {
            "id": "claude_others",
            "name": "Claude / Others",
            "displayName": "Claude / Others",
            "icon": "assets/claude.svg",
            "session_allowance": allowances["claude_session"],
            "weekly_allowance": allowances["claude_weekly"]
        }
    }

    for cat_key, cfg in config_map.items():
        b = raw_buckets[cat_key]
        session_allowance = cfg["session_allowance"]
        weekly_allowance = cfg["weekly_allowance"]

        if b["oldest_in_5h"]:
            reset_5h_ts = (b["oldest_in_5h"] + five_hours_ms) / 1000.0
        else:
            reset_5h_ts = now_ts + (5 * 3600)

        if b["oldest_in_7d"]:
            reset_7d_ts = (b["oldest_in_7d"] + seven_days_ms) / 1000.0
        else:
            reset_7d_ts = now_ts + (7 * 24 * 3600)

        reset_5h_dt = datetime.fromtimestamp(reset_5h_ts, tz=timezone.utc)
        reset_7d_dt = datetime.fromtimestamp(reset_7d_ts, tz=timezone.utc)

        session_percent = min(1.0, round(b["session_prompts"] / float(max(1, session_allowance)), 4))
        weekly_percent = min(1.0, round(b["weekly_prompts"] / float(max(1, weekly_allowance)), 4))

        if b["oldest_in_7d"]:
            elapsed_week_ratio = min(1.0, (now_ts_ms - b["oldest_in_7d"]) / float(seven_days_ms))
        else:
            elapsed_week_ratio = 0.5
        behind_pace = (weekly_percent > (elapsed_week_ratio + 0.15)) and (b["weekly_prompts"] > 10)

        weekly_tokens = sum(b["weekly_model_tokens"].values())
        today_tokens = sum(b["today_model_tokens"].values())
        if weekly_tokens == 0 and b["weekly_prompts"] > 0:
            weekly_tokens = b["weekly_prompts"] * 2500
        if today_tokens == 0 and b["today_prompts"] > 0:
            today_tokens = b["today_prompts"] * 2500

        # Build model_usage_list across weekly models (variants grouped together)
        model_usage_list = []
        for m, t in b["weekly_model_tokens"].items():
            model_usage_list.append({
                "name": m,
                "tokens": t,
                "prompts": b["weekly_model_prompts"].get(m, 0),
                "todayTokens": b["today_model_tokens"].get(m, 0),
                "todayPrompts": b["today_model_prompts"].get(m, 0)
            })

        if not model_usage_list and b["models_seen"]:
            top_m = list(b["models_seen"])[0]
            model_usage_list.append({
                "name": top_m,
                "tokens": weekly_tokens,
                "prompts": b["weekly_prompts"],
                "todayTokens": today_tokens,
                "todayPrompts": b["today_prompts"]
            })
        elif not model_usage_list:
            default_label = "Gemini 3.8 Flash" if cat_key == "gemini" else "Claude Opus 4.6"
            model_usage_list.append({
                "name": default_label,
                "tokens": weekly_tokens,
                "prompts": b["weekly_prompts"],
                "todayTokens": today_tokens,
                "todayPrompts": b["today_prompts"]
            })

        # Sort heavier / most used models first
        model_usage_list.sort(key=lambda x: x["tokens"], reverse=True)
        active_cat_model = model_usage_list[0]["name"]

        categories[cat_key] = {
            "id": cfg["id"],
            "name": cfg["name"],
            "displayName": cfg["displayName"],
            "icon": cfg["icon"],
            "activeModel": active_cat_model,
            "todayPrompts": b["today_prompts"],
            "todayTotalTokens": today_tokens,
            "weeklyPrompts": b["weekly_prompts"],
            "weeklyTotalTokens": weekly_tokens,
            "totalPrompts": b["total_prompts"],
            "activeDays": len(b["active_dates"]),
            "behindPace": behind_pace,
            "session": {
                "used": b["session_prompts"],
                "allowance": session_allowance,
                "percent": session_percent,
                "resetsAt": reset_5h_dt.isoformat(),
                "resetRemainingSeconds": max(0, int(reset_5h_ts - now_ts))
            },
            "weekly": {
                "used": b["weekly_prompts"],
                "allowance": weekly_allowance,
                "percent": weekly_percent,
                "resetsAt": reset_7d_dt.isoformat(),
                "resetRemainingSeconds": max(0, int(reset_7d_ts - now_ts)),
                "behindPace": behind_pace
            },
            "modelUsageList": model_usage_list
        }

    return categories


def get_model_and_tier(paths):
    tier_label = "Gemini Code Assist"
    model_name = "Gemini 3.8 Flash (High)"
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

        gemini_cat = payload["categories"]["gemini"]
        claude_cat = payload["categories"]["claude_others"]

        # 1. Sync gemini.json
        gemini_state = {
            "schemaVersion": 1,
            "id": "gemini",
            "name": "Gemini",
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "ready": payload["ready"],
            "hasLocalStats": True,
            "todayPrompts": gemini_cat["todayPrompts"],
            "todaySessions": 0,
            "todayTotalTokens": gemini_cat["todayTotalTokens"],
            "todayTokensByModel": {
                gemini_cat["activeModel"]: gemini_cat["todayTotalTokens"]
            },
            "recentDays": [],
            "totalPrompts": gemini_cat["totalPrompts"],
            "totalSessions": 0,
            "activeDays": gemini_cat["activeDays"],
            "activeDates": [],
            "modelUsage": {
                gemini_cat["activeModel"]: {
                    "inputTokens": int(gemini_cat["todayTotalTokens"] * 0.7),
                    "outputTokens": int(gemini_cat["todayTotalTokens"] * 0.3),
                    "cacheReadInputTokens": 0,
                    "cacheCreationInputTokens": 0
                }
            },
            "limits": [
                {
                    "label": "5h window",
                    "percent": gemini_cat["session"]["percent"],
                    "resetsAt": gemini_cat["session"]["resetsAt"]
                },
                {
                    "label": "Weekly (7-day)",
                    "percent": gemini_cat["weekly"]["percent"],
                    "resetsAt": gemini_cat["weekly"]["resetsAt"]
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

        # 2. Sync claude.json for Omarchy agents panel
        claude_state = {
            "schemaVersion": 1,
            "id": "claude",
            "name": "Claude Code",
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "ready": payload["ready"] and (claude_cat["totalPrompts"] > 0),
            "hasLocalStats": True,
            "todayPrompts": claude_cat["todayPrompts"],
            "todaySessions": 0,
            "todayTotalTokens": claude_cat["todayTotalTokens"],
            "todayTokensByModel": {
                claude_cat["activeModel"]: claude_cat["todayTotalTokens"]
            },
            "recentDays": [],
            "totalPrompts": claude_cat["totalPrompts"],
            "totalSessions": 0,
            "activeDays": claude_cat["activeDays"],
            "activeDates": [],
            "modelUsage": {
                claude_cat["activeModel"]: {
                    "inputTokens": int(claude_cat["todayTotalTokens"] * 0.7),
                    "outputTokens": int(claude_cat["todayTotalTokens"] * 0.3),
                    "cacheReadInputTokens": 0,
                    "cacheCreationInputTokens": 0
                }
            },
            "limits": [
                {
                    "label": "Session (5-hour)",
                    "percent": claude_cat["session"]["percent"],
                    "resetsAt": claude_cat["session"]["resetsAt"]
                },
                {
                    "label": "Weekly (7-day)",
                    "percent": claude_cat["weekly"]["percent"],
                    "resetsAt": claude_cat["weekly"]["resetsAt"]
                }
            ],
            "tierLabel": "Anthropic / Antigravity",
            "usageStatusText": "" if payload["ready"] else "Waiting for auth",
            "authHelpText": "Select Claude model in `agy`."
        }

        tmp_claude = paths["state_dir"] / ".claude.tmp"
        final_claude = paths["state_dir"] / "claude.json"
        with open(tmp_claude, "w", encoding="utf-8") as f:
            json.dump(claude_state, f, indent=2)
        tmp_claude.replace(final_claude)

    except Exception as e:
        sys.stderr.write(f"Warning: could not write omarchy state: {e}\n")


def main():
    parser = argparse.ArgumentParser(description="Collect Gemini & Claude/Others usage stats for Omarchy")
    parser.add_argument("--session-allowance", type=int, default=DEFAULT_SESSION_ALLOWANCE, help="Gemini 5-hour session prompt allowance")
    parser.add_argument("--weekly-allowance", type=int, default=DEFAULT_WEEKLY_ALLOWANCE, help="Gemini 7-day prompt allowance")
    parser.add_argument("--claude-session-allowance", type=int, default=DEFAULT_CLAUDE_SESSION_ALLOWANCE, help="Claude/Others 5-hour session prompt allowance")
    parser.add_argument("--claude-weekly-allowance", type=int, default=DEFAULT_CLAUDE_WEEKLY_ALLOWANCE, help="Claude/Others 7-day prompt allowance")
    parser.add_argument("--limits-only", action="store_true", help="Fast output with limits only")
    parser.add_argument("--no-sync", action="store_true", help="Do not write to ~/.local/state/omarchy/agents/usage/*.json")
    args = parser.parse_args()

    paths = get_paths()
    meta = get_model_and_tier(paths)
    allowances = {
        "gemini_session": args.session_allowance,
        "gemini_weekly": args.weekly_allowance,
        "claude_session": args.claude_session_allowance,
        "claude_weekly": args.claude_weekly_allowance
    }

    categories = parse_history_by_category(paths, allowances, meta["model_name"])
    active_category = get_category(meta["model_name"])
    active_cat_data = categories.get(active_category) or categories["gemini"]

    result = {
        "id": "gemini",
        "name": "Gemini",
        "displayName": "Google Gemini",
        "agentName": "Antigravity",
        "model": canonical_model(meta["model_name"]),
        "tier": meta["tier_label"],
        "ready": meta["ready"],
        "activeCategory": active_category,
        "categories": categories,

        # Root-level conveniences mapped to active category:
        "todayPrompts": active_cat_data["todayPrompts"],
        "todayTotalTokens": active_cat_data["todayTotalTokens"],
        "weeklyPrompts": active_cat_data["weeklyPrompts"],
        "weeklyTotalTokens": active_cat_data["weeklyTotalTokens"],
        "totalPrompts": active_cat_data["totalPrompts"],
        "activeDays": active_cat_data["activeDays"],
        "behindPace": active_cat_data["behindPace"],
        "session": active_cat_data["session"],
        "weekly": active_cat_data["weekly"],
        "modelUsageList": active_cat_data["modelUsageList"],

        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "statusText": "" if meta["ready"] else "Waiting for auth"
    }

    if not args.no_sync:
        publish_omarchy_state(paths, result)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
