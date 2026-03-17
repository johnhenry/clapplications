---
name: deep-sleep
description: "Run autonomous deep sleep cycle. Loops until all skills are below 0.2 pressure or 4 cycles complete. Does not pause for input — NEVER STOP mode. Use for overnight consolidation."
disable-model-invocation: true
context: fork
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

Read the sleep orchestrator at `${CLAUDE_PLUGIN_ROOT}/skills/sleep/SKILL.md`
and execute in **autonomous deep sleep mode**.

First check pressure:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py status
```

Then loop through full N1→N2→N3→REM cycles on all skills above threshold.

**NEVER STOP.** Do not pause to ask for input. The user may be asleep
or away. Continue cycling until all skills are below 0.2 pressure or
you've completed 4 cycles. Log all results to `results.tsv`.

$ARGUMENTS
