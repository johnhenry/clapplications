#!/usr/bin/env python3
"""
relevance_scorer.py — Detect which skills were used in a conversation
and pipe relevance scores to sleep_tracker.py record.

Called by the Stop hook. Reads hook stdin (JSON with transcript_path),
parses the JSONL transcript for skill invocations and tool patterns,
then invokes sleep_tracker.py record with relevance data on stdin.

No LLM call — pure pattern matching on the transcript.
"""

import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

STATE_FILE = Path(os.environ.get("SLEEP_STATE_DIR", Path.home() / ".claude")) / "sleep_state.json"
PLUGIN_ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT", str(Path(__file__).parent.parent))
TRACKER = Path(PLUGIN_ROOT) / "scripts" / "sleep_tracker.py"

# Ambient relevance for skills not detected in conversation
AMBIENT = 0.02
# Relevance boost for directly invoked skills
DIRECT_INVOKE = 1.0
# Relevance boost for skills whose tools/patterns appear
INDIRECT_SIGNAL = 0.3


def load_tracked_skills():
    """Load skill names from sleep state."""
    if not STATE_FILE.exists():
        return set()
    try:
        state = json.loads(STATE_FILE.read_text())
        return {e["name"] for e in state.get("skills", {}).values()}
    except (json.JSONDecodeError, KeyError):
        return set()


def parse_transcript(transcript_path):
    """Parse JSONL transcript and extract signals for skill relevance."""
    skill_invocations = Counter()    # Skills directly invoked via Skill tool
    tool_usage = Counter()           # Tools used (Bash, Read, Edit, etc.)
    text_mentions = Counter()        # Skill names mentioned in messages

    tracked = load_tracked_skills()
    if not tracked:
        return {}, False

    # Match skill names via:
    # 1. Slash-command context: /skill-name
    # 2. Command-name tags: <command-name>/skill-name</command-name>
    # 3. Skill tool invocations (handled separately in tool_use parsing)
    # This avoids false positives from product names or common words in docs.
    sorted_names = sorted(tracked, key=len, reverse=True)
    escaped = '|'.join(re.escape(n) for n in sorted_names)
    slash_pattern = re.compile(
        r'/(?:\w+:)?(' + escaped + r')\b'
    ) if sorted_names else None
    command_tag_pattern = re.compile(
        r'<command-name>/(?:\w+:)?(' + escaped + r')</command-name>'
    ) if sorted_names else None

    try:
        with open(transcript_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Transcript lines are wrapped: {type, message: {role, content}}
                msg_type = msg.get("type", "")
                if msg_type not in ("user", "assistant"):
                    continue
                inner = msg.get("message", msg)
                role = inner.get("role", "")
                content = inner.get("content", "")

                # Handle content as string or list of blocks
                text_parts = []
                tool_uses = []

                if isinstance(content, str):
                    text_parts.append(content)
                elif isinstance(content, list):
                    for block in content:
                        if isinstance(block, str):
                            text_parts.append(block)
                        elif isinstance(block, dict):
                            if block.get("type") == "text":
                                text_parts.append(block.get("text", ""))
                            elif block.get("type") == "tool_use":
                                tool_uses.append(block)
                            elif block.get("type") == "tool_result":
                                text_parts.append(str(block.get("content", "")))

                # Detect direct skill invocations (Skill tool)
                for tu in tool_uses:
                    tool_name = tu.get("name", "")
                    tool_usage[tool_name] += 1

                    # Skill tool invocation — extract skill name
                    if tool_name == "Skill":
                        inp = tu.get("input", {})
                        skill_name = inp.get("skill", "")
                        # Handle qualified names like "document-skills:pdf"
                        if ":" in skill_name:
                            skill_name = skill_name.split(":")[-1]
                        if skill_name in tracked:
                            skill_invocations[skill_name] += 1

                # Scan user messages for skill references
                if role == "user":
                    full_text = " ".join(text_parts)
                    if full_text:
                        # Match /skill-name and /plugin:skill-name
                        if slash_pattern:
                            for match in slash_pattern.finditer(full_text):
                                name = match.group(1)
                                if name in tracked:
                                    text_mentions[name] += 1
                        # Match <command-name>/plugin:skill-name</command-name>
                        if command_tag_pattern:
                            for match in command_tag_pattern.finditer(full_text):
                                name = match.group(1)
                                if name in tracked:
                                    text_mentions[name] += 1

    except (FileNotFoundError, PermissionError):
        return {}, False

    # Build relevance scores
    relevance = {}
    active_skills = set()

    # Direct invocations get highest weight
    for skill, count in skill_invocations.items():
        relevance[skill] = min(DIRECT_INVOKE * count, 1.0)
        active_skills.add(skill)

    # Text mentions get indirect weight (but don't override direct)
    for skill, count in text_mentions.items():
        if skill not in active_skills:
            relevance[skill] = min(INDIRECT_SIGNAL * count, 0.8)
            active_skills.add(skill)

    # Everything else gets ambient (much lower than old default of 0.1)
    for skill in tracked:
        if skill not in relevance:
            relevance[skill] = AMBIENT

    has_signal = len(active_skills) > 0
    return relevance, has_signal


def main():
    # Read Stop hook stdin
    hook_data = {}
    if not sys.stdin.isatty():
        try:
            hook_data = json.load(sys.stdin)
        except (json.JSONDecodeError, ValueError):
            pass

    transcript_path = hook_data.get("transcript_path", "")

    relevance = {}
    if transcript_path and Path(transcript_path).exists():
        relevance, has_signal = parse_transcript(transcript_path)
    else:
        # No transcript available — fall back to uniform ambient
        tracked = load_tracked_skills()
        relevance = {s: AMBIENT for s in tracked}

    # Pipe relevance to sleep_tracker.py record
    payload = json.dumps({"relevance": relevance})
    try:
        subprocess.run(
            ["python3", str(TRACKER), "record"],
            input=payload, text=True, timeout=10,
            capture_output=True
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"Warning: Failed to record: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
