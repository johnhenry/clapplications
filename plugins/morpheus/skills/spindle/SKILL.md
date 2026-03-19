---
name: spindle
description: "Stage N2. Rapid classification bursts — sorting, tagging, filtering fragments. The workhorse stage at ~45% of cycle time. Most fragments die here."
context: fork
user-invocable: false
allowed-tools:
  - Read
---

# Spindle — Stage N2

The sorting room. Takes the noisy fragment bag from drift, classifies
each fragment, kills irrelevant noise, extracts themes.

## Inputs

From orchestrator: `fragment_bag` (from N1), `target_skill` (path),
`selectivity` (0-1, default 0.6), `cycle_number`.

## Procedure

### 1. Load Target Skill

Read SKILL.md. Build mental model of: what it does, what it handles,
what it assumes, what it declines.

### 2. Classify Each Fragment

One category + one signal strength (0-1) per fragment:

| Category | Code | Description |
|----------|------|-------------|
| Direct hit | `HIT` | Skill explicitly covers this |
| Edge case | `EDGE` | Within domain but near boundaries |
| Gap | `GAP` | Within domain but NOT covered |
| Friction | `FRIC` | User difficulty with documented workflow |
| Adjacent | `ADJ` | Related domain, different skill |
| Noise | `NOISE` | Irrelevant or unrealistically synthetic |

### 3. Filter

Survival threshold = `selectivity × 0.8`. Exceptions:
- `FRIC` and `GAP` survive at signal > 0.3 (always interesting)
- Synthetic fragments get +0.1 bonus (give creativity a chance)

| Cycle | Selectivity | Expected Kill Rate |
|-------|------------|-------------------|
| 1 | 0.7 | 60-70% |
| 2 | 0.5 | 40-50% |
| 3 | 0.3 | 20-30% |
| 4+ | 0.2 | 10-20% |

### 4. Extract Themes

If 2+ fragments touch the same area, elevate to a **theme** with
priority (high/medium/low). Themes are primary input for N3.

Flag contradictions (skill declines something users expect) and
escalations (fundamental structural issues).

### 5. Output Sorted Manifest

```yaml
sorted_manifest:
  target_skill: /path/to/SKILL.md
  input_fragments: 14
  surviving_fragments: 6
  kill_rate: 0.57
  themes: [{name, fragment_ids, priority, reason}]
  survivors: [{id, category, signal, content, tags, theme, notes}]
  discarded: {count, categories: {NOISE: 4, ADJ: 2, HIT: 2}}
  escalations: []
```

## Behavioral Rules

- **Be decisive.** If you can't classify quickly, it's NOISE.
- **Favor false positives.** Better to pass mediocre fragments to N3
  than kill one that would have produced insight in REM.
- **Don't generate.** Spindle classifies, it doesn't create new fragments.
