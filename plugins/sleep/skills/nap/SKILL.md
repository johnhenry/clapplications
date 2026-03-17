---
name: nap
description: "Quick light sleep cycle on a specific skill — N1 drift scan + N2 spindle triage only, no deep analysis or dreaming. Use when user says 'nap on [skill]'."
disable-model-invocation: true
context: fork
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
---

Run a light sleep cycle (N1→N2 only) on the specified skill.

Target: $ARGUMENTS

If no target specified, check pressure and pick the highest-pressure skill:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py check
```

Read `${CLAUDE_PLUGIN_ROOT}/skills/drift/SKILL.md` for N1 instructions
and `${CLAUDE_PLUGIN_ROOT}/skills/spindle/SKILL.md` for N2 instructions.

Run them in sequence on the target skill. Report the sorted manifest —
which fragments survived triage, what themes emerged, and whether a
full sleep cycle is warranted.
