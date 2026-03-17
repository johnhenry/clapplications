---
name: sleep
description: "Run a sleep cycle to consolidate and improve skills. Use when the user says 'sleep', 'run a sleep cycle', or 'consolidate skills'. Checks pressure levels and dispatches the N1→N2→N3→REM pipeline."
disable-model-invocation: true
context: fork
hooks:
  SessionStart:
    - matcher: "startup"
      hooks:
        - type: command
          command: "python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py check"
          once: true
  Stop:
    - matcher: ""
      hooks:
        - type: prompt
          prompt: |
            Given the tool use that just completed, assess which skills from
            this list were exercised: $TRACKED_SKILLS
            Return JSON: {"relevance": {"skill_name": 0.0-1.0, ...}}
            Only include skills with relevance > 0.1. Be brief.
          model: haiku
  Setup:
    - matcher: "maintenance"
      hooks:
        - type: command
          command: "python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py init"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

# Sleep — The Orchestrator

This is the `program.md` of the sleep skills suite. The human iterates
on this document to tune the autonomous skill consolidation system.
The sleep skills themselves iterate on OTHER skills. This file is the
one the human improves.

> *The idea: give an AI agent your skills and let it experiment
> autonomously overnight. It generates edge cases, tests patches,
> checks if the skill improved, keeps or discards, and repeats. You
> wake up in the morning to a dream journal and (hopefully) better
> skills.* — adapted from Karpathy's autoresearch

---

## What This System Optimizes

**Primary metric**: `patch_acceptance_rate` — the fraction of proposed
patches the user actually applies. Higher is better. A low rate means
dreams aren't producing useful insights.

**Secondary metrics**:
- `coverage_score` — fraction of real usage patterns covered by skill instructions
- `cruft_score` — unnecessary complexity in skills (lower is better)
- `insight_rate` — patches proposed per dream (target: 0.05-0.15)

**Constraints**:
- Never auto-apply patches. User always decides.
- Patches must be 1-3 lines. Larger findings are feature requests.
- Don't bloat skills. Simplicity is a feature.
- Don't break working skills. A patch that helps edge cases but
  degrades common cases is net negative.

---

## The Two Processes

### Process S — Homeostatic Pressure

Every conversation is metabolic activity. Pressure accumulates per-skill:

```
pressure(t) = 1 - e^(-t / τ)
```

- `t` = weighted conversations since last sleep
- `τ` = skill-specific time constant (default 20, auto-tuned by insight_rate)
- Saturates toward 1.0 — you can't accumulate infinite sleep debt

Thresholds: <0.2 rested, 0.2-0.4 drowsy, 0.4-0.7 moderate, 0.7+ heavy.

### Process C — Circadian Rhythm

A Desktop scheduled task fires at a fixed cadence (default: nightly).
Opens its own session. Runs autonomously. The SessionStart hook provides
a softer check on every session start.

### Interaction

| Pressure | Gate | Depth |
|----------|------|-------|
| Low | Closed | Nothing |
| Low | Open | Micro-nap (N1 only) |
| Moderate | Open | Standard (2 cycles) |
| High | Any | Deep (3-4 cycles, NEVER STOP until rested) |

---

## Cycle Architecture

```
N1 (drift) → N2 (spindle) → N3 (consolidate) → REM (dream)
                                                      │
                                                [eval loop]
                                                mutate → test → measure
                                                keep if improved
                                                discard if not
                                                      │
                                                ◄─────┘ next cycle
```

Each successive cycle: N1 scans wider, N2 filters less, N3 gets
shorter, REM gets longer. Mirrors biological sleep architecture.

### Cycle Depth Profiles

| Depth | Cycles | Stages | REM Eval |
|-------|--------|--------|----------|
| Micro-nap | 1 partial | N1 only | No |
| Light | 1 | N1→N2 | No |
| Standard | 2 | Full pipeline | Yes, 2-3 evals per dream |
| Deep | 3-4 | Full pipeline, extended REM | Yes, full eval loop |

---

## Autonomous Overnight Mode

**NEVER STOP.** Once the sleep loop begins (via Desktop scheduled task
or explicit `deep sleep` command), do NOT pause to ask the human.
The human may be asleep or away. Continue cycling until:

1. All tracked skills are below 0.2 pressure, OR
2. Maximum cycle count is reached (default: 4), OR
3. Session context is approaching compaction threshold

If you run out of fragment material, scan older conversations. If no
conversations exist, generate synthetic fragments and dream about those.
If all dreams score 0, that's fine — the skills are robust. Log it and
move to the next skill.

**Log everything.** Every dream scenario, every eval result, every
patch proposed or discarded. Append to `results.tsv`. Commit dream
journals to the `dreams` branch if git is available.

---

## Dispatch Protocol

### 1. Read State

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py status
```

### 2. Determine Targets

Rank skills by effective pressure (pressure + debt × 0.5). Select
based on cycle depth: micro-nap = top 1, light = top 3, standard =
top 5, deep = all above threshold.

### 3. Execute Pipeline

For each target skill, dispatch stage skills as subagents:

**N1 (drift)** — Spawn as Agent with `drift` instructions.
Pass: target_skill, scan_depth, recency_bias, randomness, cycle_number.
Collect: fragment bag.

**N2 (spindle)** — Spawn as Agent with `spindle` instructions.
Pass: fragment bag, target_skill, selectivity, cycle_number.
Collect: sorted manifest.

**N3 (consolidate)** — Spawn as Agent with `consolidate` instructions.
Pass: sorted manifest, target_skill, prune_mode, cycle_number.
Collect: structural audit. Record baseline metrics in results.tsv.

**REM (dream)** — Spawn as Agent with `dream` instructions.
Pass: structural audit, surviving fragments, target_skill, intensity.
Collect: dream journal with tested patches.

### 4. Record Results

For each completed cycle, append to `${CLAUDE_PLUGIN_ROOT}/results.tsv`:

```
timestamp	skill	cycle	depth	fragments_scanned	fragments_survived	dreams_generated	patches_proposed	patches_tested	patches_passed_eval	pressure_before	pressure_after	notes
```

### 5. Update State

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py reset [depth]
```

### 6. Loop or Report

If autonomous mode and pressure still elevated: begin next cycle.
If pressure resolved or max cycles reached: write summary, present
dream journals with tested patches to user.

---

## Triggering

### Automatic (recommended)

**Desktop scheduled task** — The circadian rhythm. Create via Claude
Code Desktop:

```
Schedule: 0 3 * * * (3am daily, or whatever suits your rhythm)
Prompt: "Read ${CLAUDE_PLUGIN_ROOT}/sleep/SKILL.md. Run an autonomous
         sleep cycle on all skills above pressure threshold. Use deep
         sleep mode. Do not stop to ask for input. Log all results."
Permission mode: Auto accept edits
Worktree: enabled (isolate from working state)
```

**Session-scoped /loop** — Intra-session micro-naps for long sessions:

```
/loop 30m "Run sleep_tracker.py check. If any skill pressure > 0.4,
           run a light N1→N2 triage pass on the highest-pressure skill.
           Report findings briefly."
```

### Manual

| Command | Action |
|---------|--------|
| `sleep` | Auto-detect pressure, run appropriate cycle |
| `sleep status` | Show pressure gauges |
| `nap [skill]` | Light cycle on specific skill |
| `deep sleep` | Autonomous deep cycle, NEVER STOP |
| `sleep history` | Past results from results.tsv |
| `snooze` | Defer, accumulate debt |
| `insomnia` | Debug — full state dump |

---

## State

All state in `~/.claude/sleep_state.json`. The tracker script handles
all I/O. See `schemas/sleep_state.schema.json`.

The tracker is deliberately thin — pure math and JSON read/write. All
intelligence lives in prompt hooks (relevance assessment) and agent
hooks (fragment extraction, eval). The tracker never reasons about
content.

---

## Meta-Improvement

This orchestrator is itself subject to dreaming. If the dream skill
is applied to `sleep/SKILL.md`, it can propose patches to the sleep
process itself — adjusting thresholds, cycle profiles, dispatch order,
or eval criteria. The human reviews these meta-patches with the same
keep/discard discipline as any other patch.

Over time, the `results.tsv` becomes the training data for improving
this document. Analyze it: which mutation strategies produce accepted
patches? Which skills benefit most? Which cycle depths are most
productive? Use those findings to refine these instructions.

---

## Anti-Patterns

- **Don't sleep too often.** If you're sleeping every 5 conversations, τ is too low.
- **Don't skip micro-naps.** They're cheap and catch things early.
- **Don't ignore debt.** Pressure 0.3 + debt 0.5 needs deeper sleep than pressure 0.3 alone.
- **Don't force insights.** 60% of dreams should score 0. That's correct.
- **Don't trust untested patches.** REM eval exists for a reason. Mental simulation alone is insufficient — test patches before proposing them.
