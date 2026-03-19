#!/usr/bin/env python3
"""
sleep_tracker.py — Thin state persistence for the sleep skills suite.

All intelligence lives in prompt/agent hooks. This script does ONLY:
- JSON read/write to ~/.claude/sleep_state.json
- Pressure math (saturating exponential)
- Skill discovery (scanning directories for SKILL.md files)

Commands:
    init              Discover skills, create initial state
    record            Increment conversation counter, recalculate pressure
    record-dream      Log a dream completion to state
    check             Return JSON for SessionStart additionalContext
    status            Print pressure gauges (human-readable)
    reset [depth]     Reset pressure after sleep cycle
    snooze            Defer sleep, accumulate debt
    history           Print recent sleep history
    apply [skill]     Record that a patch was applied
    discard [skill]   Record that a patch was discarded
"""

import json, math, os, sys
from datetime import datetime, timezone
from pathlib import Path

STATE_DIR = Path(os.environ.get("SLEEP_STATE_DIR", Path.home() / ".claude"))
STATE_FILE = STATE_DIR / "sleep_state.json"
PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))

DEFAULT_TAU = 20
DEFAULT_CIRCADIAN_INTERVAL = 50
P_MAX = 1.0
THRESHOLDS = {"rested": 0.2, "drowsy": 0.4, "moderate": 0.7, "heavy": 0.9}

# Skills belonging to the sleep plugin itself — excluded from tracking
SLEEP_SKILL_NAMES = {"sleep", "sleep-status", "deep-sleep", "nap", "snooze",
                     "dream", "drift", "spindle", "consolidate"}


def load():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return None

def save(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def pressure(t, tau):
    return P_MAX * (1 - math.exp(-t / tau)) if t > 0 else 0.0

def effective(p, debt):
    return p + debt * 0.5

def depth_for(eff):
    if eff >= THRESHOLDS["heavy"]: return "deep"
    if eff >= THRESHOLDS["moderate"]: return "standard"
    if eff >= THRESHOLDS["drowsy"]: return "light"
    if eff >= THRESHOLDS["rested"]: return "micro-nap"
    return None

def label(eff):
    if eff >= THRESHOLDS["heavy"]: return "🔴 heavy"
    if eff >= THRESHOLDS["moderate"]: return "🟠 moderate"
    if eff >= THRESHOLDS["drowsy"]: return "🟡 drowsy"
    if eff >= THRESHOLDS["rested"]: return "🔵 light"
    return "🟢 rested"

def _gather_skill_dirs():
    """
    Collect all directories to scan for SKILL.md files.
    Sources (in priority order):

    1. Built-in skills:       /mnt/skills/public, /mnt/skills/examples
    2. Personal skills:       ~/.claude/skills/
    3. Project skills:        $CLAUDE_PROJECT_DIR/.claude/skills/
    4. Installed plugins:     ~/.claude/plugins/*/skills/
                              ~/.claude/plugins/marketplaces/*/*/skills/
    5. Extra paths:           SLEEP_EXTRA_SKILL_DIRS env var (colon-separated)
    """
    dirs = []

    # 1. Built-in (claude.ai / Claude Code bundled)
    for p in [Path("/mnt/skills/public"), Path("/mnt/skills/examples")]:
        if p.exists():
            dirs.append(("builtin", p))

    # 2. Personal skills
    personal = Path.home() / ".claude" / "skills"
    if personal.exists():
        dirs.append(("personal", personal))

    # 3. Project-scoped skills
    project_skills = PROJECT_DIR / ".claude" / "skills"
    if project_skills.exists() and project_skills.resolve() != personal.resolve():
        dirs.append(("project", project_skills))

    # 4. Installed plugins — scan for skills/ subdirectories
    plugins_dir = Path.home() / ".claude" / "plugins"
    if plugins_dir.exists():
        # Direct plugin installs: ~/.claude/plugins/<plugin>/skills/
        for plugin_dir in plugins_dir.iterdir():
            if plugin_dir.name == "marketplaces":
                continue  # Handle separately
            sk = plugin_dir / "skills"
            if sk.is_dir():
                dirs.append(("plugin", sk))

        # Marketplace installs: ~/.claude/plugins/marketplaces/<mkt>/<plugin>/skills/
        mkts = plugins_dir / "marketplaces"
        if mkts.exists():
            for mkt in mkts.iterdir():
                if not mkt.is_dir():
                    continue
                for plugin_dir in mkt.iterdir():
                    sk = plugin_dir / "skills"
                    if sk.is_dir():
                        dirs.append(("plugin", sk))

    # 5. Extra paths from env (colon-separated)
    extra = os.environ.get("SLEEP_EXTRA_SKILL_DIRS", "")
    for p in extra.split(":"):
        p = p.strip()
        if p and Path(p).exists():
            dirs.append(("extra", Path(p)))

    return dirs


def _scan_dir_for_skills(skills_dir):
    """Scan a skills directory for SKILL.md files. Returns {path: name}."""
    found = {}
    if not skills_dir.is_dir():
        return found
    for entry in skills_dir.iterdir():
        if not entry.is_dir():
            continue
        sm = entry / "SKILL.md"
        if sm.exists():
            found[str(sm)] = entry.name
    return found


def discover_skills():
    """
    Discover all trackable skills across all sources.
    Excludes the sleep plugin's own skills.
    Deduplicates by name (first found wins — priority order).
    """
    skills = {}
    seen_names = set()
    sources_summary = {}

    for source_type, skills_dir in _gather_skill_dirs():
        found = _scan_dir_for_skills(skills_dir)
        for path, name in found.items():
            # Skip our own skills
            if name in SLEEP_SKILL_NAMES:
                continue
            # Deduplicate by name (first source wins)
            if name in seen_names:
                continue
            seen_names.add(name)
            skills[path] = {
                "name": name, "source": source_type, "tau": DEFAULT_TAU,
                "conversations_since_sleep": 0, "pressure": 0.0,
                "last_sleep": None, "last_sleep_depth": None,
                "debt": 0.0, "fragments_pending": 0,
                "total_dreams": 0, "total_patches_proposed": 0,
                "total_patches_applied": 0, "total_patches_discarded": 0,
                "insight_rate": 0.0, "last_audit_health": None,
            }
            sources_summary[source_type] = sources_summary.get(source_type, 0) + 1

    return skills, sources_summary

def cmd_init():
    skills, sources = discover_skills()
    state = {
        "version": "2.0.0",
        "global": {
            "total_conversations": 0, "last_circadian_gate": None,
            "circadian_interval": DEFAULT_CIRCADIAN_INTERVAL,
            "next_gate_at": DEFAULT_CIRCADIAN_INTERVAL, "caffeine": None,
        },
        "skills": skills, "history": [],
    }
    # If state already exists, preserve pressure data for known skills
    existing = load()
    if existing:
        for path, entry in existing.get("skills", {}).items():
            if path in state["skills"]:
                # Preserve accumulated data, update source
                for key in ["conversations_since_sleep", "pressure", "last_sleep",
                            "last_sleep_depth", "debt", "fragments_pending",
                            "total_dreams", "total_patches_proposed",
                            "total_patches_applied", "total_patches_discarded",
                            "insight_rate", "last_audit_health", "tau"]:
                    if key in entry:
                        state["skills"][path][key] = entry[key]
        state["global"] = existing.get("global", state["global"])
        state["history"] = existing.get("history", [])
    save(state)
    total = len(skills)
    summary = ", ".join(f"{v} {k}" for k, v in sorted(sources.items()))
    print(f"Initialized. Tracking {total} skills ({summary}).")

def cmd_record():
    state = load()
    if not state: state = (cmd_init(), load())[1]
    state["global"]["total_conversations"] += 1
    # Read relevance from stdin if provided by prompt hook
    relevance = {}
    if not sys.stdin.isatty():
        try:
            data = json.load(sys.stdin)
            relevance = data.get("relevance", {})
        except: pass
    for path, entry in state["skills"].items():
        r = relevance.get(entry["name"], 0.1)  # Default ambient
        entry["conversations_since_sleep"] += r
        entry["pressure"] = pressure(entry["conversations_since_sleep"], entry["tau"])
    save(state)

def cmd_record_dream():
    state = load()
    if not state: return
    if not sys.stdin.isatty():
        try:
            data = json.load(sys.stdin)
            skill = data.get("skill_path", "")
            if skill in state["skills"]:
                e = state["skills"][skill]
                e["total_dreams"] = e.get("total_dreams", 0) + data.get("dreams", 0)
                e["total_patches_proposed"] += data.get("patches_proposed", 0)
                if e["total_dreams"] > 0:
                    e["insight_rate"] = e["total_patches_proposed"] / e["total_dreams"]
        except: pass
    save(state)

def cmd_check():
    state = load()
    if not state:
        print(json.dumps({"needs_sleep": False, "message": "No state. Run claude --maintenance."}))
        return
    total = state["global"]["total_conversations"]
    gate = state["global"]["next_gate_at"]
    gate_open = total >= gate
    needs = []
    for path, e in state["skills"].items():
        eff = effective(e["pressure"], e.get("debt", 0))
        if eff >= THRESHOLDS["rested"]:
            needs.append({"name": e["name"], "path": path,
                         "pressure": round(e["pressure"], 3),
                         "debt": round(e.get("debt", 0), 3),
                         "depth": depth_for(eff)})
    needs.sort(key=lambda x: x["pressure"], reverse=True)
    if not needs:
        print(json.dumps({"needs_sleep": False, "message": "All skills rested."}))
    elif needs[0]["pressure"] >= THRESHOLDS["moderate"] or gate_open:
        top = needs[0]
        print(json.dumps({
            "needs_sleep": True, "gate_open": gate_open,
            "message": f"Sleep {'recommended' if top['pressure'] >= 0.7 else 'available'}: "
                       f"{len(needs)} skill(s) elevated. Highest: {top['name']} at {top['pressure']:.2f}. "
                       f"Say 'sleep' to run a cycle or 'snooze' to defer.",
            "skills": needs,
        }))
    else:
        print(json.dumps({"needs_sleep": False,
            "message": f"Light pressure on {len(needs)} skill(s). Gate in {gate - total} convos.",
            "skills": needs}))

def cmd_status():
    state = load()
    if not state: return print("No state. Run: claude --maintenance")
    g = state["global"]
    print(f"Conversations: {g['total_conversations']}  Gate: {g['next_gate_at']} (in {g['next_gate_at'] - g['total_conversations']})")
    if (g.get("caffeine") or {}).get("active"):
        print(f"☕ Caffeine: {g['caffeine']['gates_remaining']} gates suppressed")

    # Group by source
    by_source = {}
    for _, e in state["skills"].items():
        src = e.get("source", "unknown")
        by_source.setdefault(src, []).append(e)

    print()
    for src in ["builtin", "personal", "project", "plugin", "extra", "unknown"]:
        entries = by_source.get(src, [])
        if not entries:
            continue
        src_label = {"builtin": "Built-in", "personal": "Personal",
                     "project": "Project", "plugin": "Plugin",
                     "extra": "Extra", "unknown": "Other"}.get(src, src)
        print(f"  [{src_label}]")
        for e in sorted(entries, key=lambda x: effective(x["pressure"], x.get("debt", 0)), reverse=True):
            eff = effective(e["pressure"], e.get("debt", 0))
            bar = "█" * int(e["pressure"] * 20) + "░" * (20 - int(e["pressure"] * 20))
            d = depth_for(eff)
            line = f"    {e['name']:<22} [{bar}] {e['pressure']:.2f} {label(eff)}"
            if e.get("debt", 0) > 0.01: line += f" (debt:{e['debt']:.2f})"
            if d: line += f" → {d}"
            if e.get("total_dreams", 0) > 0: line += f"  [{e['total_dreams']}d/{e['total_patches_proposed']}p]"
            print(line)
        print()

def cmd_reset():
    depth = sys.argv[2] if len(sys.argv) > 2 else "standard"
    state = load()
    if not state: return
    decay = {"micro-nap": 0.2, "light": 0.5, "standard": 0.8, "deep": 0.95}.get(depth, 0.8)
    now = datetime.now(timezone.utc).isoformat()
    pb, pa, processed = {}, {}, []
    for path, e in state["skills"].items():
        pb[e["name"]] = round(e["pressure"], 3)
        e["conversations_since_sleep"] = int(e["conversations_since_sleep"] * (1 - decay))
        e["pressure"] = pressure(e["conversations_since_sleep"], e["tau"])
        e["debt"] = max(0, e.get("debt", 0) * (1 - decay))
        e["last_sleep"], e["last_sleep_depth"] = now, depth
        pa[e["name"]] = round(e["pressure"], 3)
        processed.append(path)
    state["global"]["next_gate_at"] = state["global"]["total_conversations"] + state["global"]["circadian_interval"]
    state["global"]["last_circadian_gate"] = now
    state["history"].insert(0, {"timestamp": now, "depth": depth,
        "skills_processed": processed, "pressure_before": pb, "pressure_after": pa})
    state["history"] = state["history"][:50]
    save(state)
    print(json.dumps({"reset": True, "depth": depth, "skills": len(processed)}))

def cmd_snooze():
    state = load()
    if not state: return
    for _, e in state["skills"].items():
        if e["pressure"] >= THRESHOLDS["drowsy"]:
            e["debt"] = e.get("debt", 0) + e["pressure"] * 0.1
    state["global"]["next_gate_at"] = state["global"]["total_conversations"] + state["global"]["circadian_interval"]
    save(state)
    print("Snoozed. Debt accumulated.")

def cmd_patch_result(applied):
    skill = sys.argv[2] if len(sys.argv) > 2 else None
    state = load()
    if not state or not skill: return
    for path, e in state["skills"].items():
        if e["name"] == skill or path == skill:
            if applied: e["total_patches_applied"] = e.get("total_patches_applied", 0) + 1
            else: e["total_patches_discarded"] = e.get("total_patches_discarded", 0) + 1
            break
    save(state)

def cmd_history():
    state = load()
    if not state: return print("No history.")
    for h in state.get("history", [])[:10]:
        ts = h["timestamp"][:19]
        d = h.get("depth", "?")
        n = len(h.get("skills_processed", []))
        print(f"  {ts}  {d:<10}  {n} skills")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    {"init": cmd_init, "record": cmd_record, "record-dream": cmd_record_dream,
     "check": cmd_check, "status": cmd_status, "reset": cmd_reset,
     "snooze": cmd_snooze, "apply": lambda: cmd_patch_result(True),
     "discard": lambda: cmd_patch_result(False), "history": cmd_history,
    }.get(cmd, lambda: print(__doc__))()
