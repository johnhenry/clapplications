---
name: snooze
description: "Defer sleep. Accumulates debt — like hitting the snooze button. Pressure doesn't go away, it just gets masked. Use when user says 'snooze', 'not now', or 'later'."
---

Defer the current sleep recommendation.

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py snooze
```

Warn the user: pressure doesn't disappear when snoozed. It accumulates
as debt, which means the next sleep cycle will need to be deeper.
Like real caffeine — it masks the tiredness but the adenosine keeps building.
