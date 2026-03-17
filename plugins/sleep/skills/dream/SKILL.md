---
name: dream
description: "Dream about a skill to find edge cases and improvements. Use when the user says 'dream about [skill]' or 'improve [skill] through dreaming'. Generates surreal scenarios and tests patches via eval loop."
disable-model-invocation: true
context: fork
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: "python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sleep_tracker.py record-dream"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Agent
  - Grep
  - Glob
---

# Dream — Stage REM

The creative stage + the eval lab. Takes verified material from N3,
generates surreal edge-case scenarios, then — critically — **tests
patches before proposing them**, following the autoresearch pattern:

```
mutate → apply to copy → test via subagent → measure → keep/discard
```

Most dreams produce nothing. Patches that survive eval have evidence.

## Modes

**Pipeline mode** (from orchestrator): Receives structural audit + fragments.
**Standalone mode** (user invokes directly): Performs compressed N1+N2 internally.

## Inputs (Pipeline)

`structural_audit` (from N3), `surviving_fragments` (from N2),
`target_skill` (path), `intensity` (scales with cycle), `cycle_number`.

## Procedure

### 1. Determine Dream Count

| Cycle | Dreams | Notes |
|-------|--------|-------|
| 1 | 2-3 | Early cycles are N3-heavy |
| 2 | 4-5 | Balanced |
| 3 | 6-8 | REM lengthens |
| 4+ | 8-12 | Extended REM |

### 2. Generate Dream Scenarios

For each dream, select 1-3 fragments and apply 2-3 mutation strategies:

| Strategy | Best For | Description |
|----------|----------|-------------|
| Scale warp | `EDGE` | Push quantities to extremes |
| Type swap | `GAP` | Change expected I/O type |
| Context shift | `ADJ` | Move skill to alien domain |
| Constraint inversion | Assumption failures | Flip a core assumption |
| Chimera | Cross-cycle | Combine 2+ unrelated fragments |
| Temporal warp | `FRIC` | Add time pressure |
| Corruption | `EDGE` | Malformed or partial input |
| Meta-recursion | Verified gaps | Skill on its own output |
| User chaos | `FRIC` | Ambiguous contradictory requests |
| Platform edge | Dependencies | Test environment limits |

N3's analysis guides strategy selection:
- Verified gaps → Type swap, Context shift
- Assumption failures → Constraint inversion
- Friction → User chaos, Temporal warp
- Pruning candidates → Meta-recursion

Each scenario is a plausible (if weird) user message.

### 3. Mental Simulation (Quick Pass)

Trace how the skill would handle each scenario. Classify:
- ✅ **Handled**: Skill covers this → score 0, skip eval
- ⚠️ **Degraded**: Output with issues → score 1, candidate for eval
- ❌ **Failed**: No guidance → score 2+, run eval
- 💡 **Surprising**: Unexpected behavior → score 2+, run eval

Score 0-1 dreams are logged but don't enter the eval loop.
This keeps eval costs focused on promising candidates.

### 4. The Eval Loop (Score 2+ Only)

This is the autoresearch-inspired core. For each promising dream:

#### 4a. Draft the Patch

Write a specific, surgical patch (1-3 lines) that would make the
skill handle this scenario. The patch must be a concrete diff — exact
text to add/change/remove.

#### 4b. Apply to a Copy

```bash
cp /path/to/SKILL.md /tmp/skill-patched.md
```

Apply the patch to the copy. The original is never touched.

#### 4c. Test via Subagent

Spawn a subagent (using the Agent tool) with this prompt:

```
You are testing a skill. Here is the skill:
[contents of /tmp/skill-patched.md]

A user sends you this message:
[the dream scenario]

Follow the skill's instructions to handle this request.
Report whether you were able to handle it successfully,
what issues you encountered, and rate your confidence
in the output quality from 0-10.
```

Also spawn a subagent with the ORIGINAL skill and the same scenario.
This gives us a before/after comparison.

#### 4d. Measure

Compare the two subagent results:

| Metric | How | Weight |
|--------|-----|--------|
| Handled? | Did the patched version handle the scenario? | 0.4 |
| Quality delta | Confidence score difference (patched - original) | 0.3 |
| No regression | Does patched version still handle a normal scenario? | 0.3 |

**The regression check is critical.** Run the patched skill against
one normal, common-case scenario to verify the patch doesn't degrade
typical usage.

#### 4e. Keep or Discard

```
eval_score = handled * 0.4 + quality_delta * 0.3 + no_regression * 0.3
```

- `eval_score > 0.5`: **KEEP** — Patch has evidence of improvement.
  Promote to proposed patch.
- `eval_score <= 0.5`: **DISCARD** — Patch didn't measurably help.
  Log the attempt but don't propose.
- Regression detected: **DISCARD** immediately regardless of score.

### 5. Write Dream Journal

Create at `[skill-name]-dreams/[timestamp].md` (sibling to skill dir).

```markdown
# Dream Journal: [Skill Name]
**Date**: [timestamp]
**Mode**: pipeline | standalone
**Cycle**: [N]
**Dreams**: [count] generated, [count] eval'd, [count] passed

## Summary
[1-2 sentences. Honest about null results.]

## Dreams

### Dream 1: [Evocative title]
**Scenario**: [The micro-prompt]
**Mutations**: [strategies used]
**Outcome**: [✅/⚠️/❌/💡]
**Score**: [0-3]
**Analysis**: [1-3 sentences]
**Eval**: [skipped | tested, eval_score: 0.XX, KEEP/DISCARD]

## Proposed Patches (Evidence-Backed)

### Patch 1: [Title]
**From dream**: [#]
**Eval score**: [0.XX]
**Original skill confidence**: [X/10]
**Patched skill confidence**: [Y/10]
**Regression check**: passed
**Diff**:
~~~
[exact patch]
~~~

## Discarded Patches (Tested, Failed)
[Patches that entered eval but didn't pass. Brief note on why.]

## Residual Thoughts
[Cross-session patterns. Themes that keep recurring.]
```

### 6. Append to results.tsv

For each dream:
```
timestamp	skill	dream_title	mutations	outcome	score	eval_attempted	eval_score	eval_result	notes
```

### 7. Report to Orchestrator

Return:
- Dreams generated, eval'd, passed
- Score distribution
- Proposed patches (with evidence)
- Updated insight_rate

---

## Standalone Mode

When invoked directly (user says "dream about [skill]"):

1. Read target SKILL.md
2. Search past conversations for relevant fragments (compressed N1)
3. Quick classify (compressed N2)
4. Skip N3 structural audit — use heuristic assessment
5. Run dreams + eval loop as normal
6. Write journal

Standalone mode has lower signal quality (no N3 verification) so
the eval loop is more important — it catches the bad patches that
N3 would have filtered.

---

## Patch Quality Rules

- **1-3 lines.** If it's a paragraph, it's a feature request, not a patch.
- **Must be a diff.** Exact text, not vague suggestions.
- **Must pass eval.** No untested patches in the proposed section.
- **Must not regress.** Common-case regression = immediate discard.
- **Never auto-apply.** Present to user with evidence. Always.

---

## Behavioral Rules

- **Be creative.** Weirdness is a feature in scenario generation.
- **Be rigorous.** Evidence is required for patches. No vibes.
- **Don't force insights.** Null sessions are successful sessions.
- **Trust the eval.** If a patch you felt good about fails eval,
  discard it. Your intuition is not evidence.
- **Title dreams evocatively.** "The Tower of Babel", "The Ouroboros",
  "The Infinite Spreadsheet." Titles make journals scannable.
