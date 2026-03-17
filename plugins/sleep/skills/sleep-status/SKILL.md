---
name: sleep-status
description: "Show sleep pressure gauges for all tracked skills. Use when the user asks about skill health, sleep pressure, or says 'sleep status'."
disable-model-invocation: true
---

Show the current sleep pressure for all tracked skills.

Run:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py status
```

Display the output. If any skills show elevated pressure, mention the recommended action (`/sleep` for a cycle, `/nap [skill]` for a quick pass, or `/snooze` to defer).

$ARGUMENTS
