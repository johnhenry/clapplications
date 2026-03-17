---
name: consolidate
description: "Stage N3. Deep structural analysis of skill against real usage. Verifies gaps, prunes cruft, measures baseline health. Produces structural audit that feeds REM. Front-loaded in early cycles."
context: fork
user-invocable: false
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Consolidate — Stage N3

Deep slow-wave analysis. ~25% of cycle time, concentrated in early
cycles. Verifies that the skill's documented facts match reality,
identifies structural drift, and optionally prunes accumulated cruft.

Also establishes the **baseline measurement** for REM's eval loop.
Without N3's audit, REM can't measure whether patches improve anything.

## Inputs

From orchestrator: `sorted_manifest` (from N2), `target_skill` (path),
`prune_mode` (bool, default false), `cycle_number`.

## Procedure

### 1. Deep Read

Read the entire SKILL.md. Build a structural inventory:
- Sections with line ranges and types (context/procedure/reference/config)
- Documented assumptions
- Explicit limitations
- Dependencies (tools, libraries)
- Complexity score (0-1)

### 2. Verify Fragments

For each surviving fragment and theme:

**Coverage verification** (`GAP` fragments): Confirm the gap is real.
Sometimes coverage exists in a non-obvious section. If confirmed,
document precisely where coverage should exist.

**Accuracy verification** (`FRIC` fragments): Are the skill's
instructions actually correct? Friction sometimes means wrong
instructions, not just incomplete ones.

**Assumption verification** (`EDGE` fragments): Which documented
assumptions break in this scenario?

Output per fragment:
```yaml
verification:
  fragment_id: f001
  result: confirmed_gap | false_gap | partial_coverage | inaccurate
  evidence: "Sections 3.1-3.7 cover formatting but never mention RTL"
  severity: minor | moderate | major
```

### 3. Prune (if prune_mode)

Identify accumulated complexity that no longer serves a purpose:
- Dead branches (no fragments or usage touch this area)
- Redundancy (multiple sections saying the same thing)
- Over-specification (exhaustive detail where a general rule suffices)
- Defensive bloat (excessive caveats without failure evidence)

Only suggest removal when confident. A false prune is worse than no
prune — you're removing institutional knowledge.

### 4. Measure Baseline

Produce health scores that REM uses as the "before" measurement:

```yaml
health_baseline:
  coverage_score: 0.75    # Fraction of real usage covered
  complexity_score: 0.65  # How complex the skill is
  drift_score: 0.3        # Usage vs documented scope divergence
  cruft_score: 0.2        # Unnecessary complexity
  gap_count: 2            # Verified gaps
  friction_count: 1       # Verified friction points
```

These scores let REM measure whether a patch actually improved things.

### 5. Output Structural Audit

```yaml
structural_audit:
  target_skill: /path/to/SKILL.md
  cycle_number: 1
  health_baseline: {coverage_score, complexity_score, drift_score, cruft_score}
  verified_gaps: [{fragment_id, gap, severity, affected_sections, recommended_location}]
  verified_friction: [{fragment_id, issue, severity}]
  assumption_failures: [{fragment_id, assumption, failure_scenario, severity}]
  prune_suggestions: []
  drift_analysis: {scope_expansions, scope_contractions, priority_mismatches}
  fragments_for_rem: [{id, reason}]
```

## N3 by Cycle

| Cycle | Depth | Prune | Focus |
|-------|-------|-------|-------|
| 1 | Full | Yes (deep sleep) | Complete structural audit |
| 2 | Moderate | No | Verify new fragments only |
| 3 | Light | No | Quick delta check |
| 4+ | Skip | N/A | N3 absent in late cycles |

## Behavioral Rules

- **Be thorough.** This is the slow stage. Read every relevant section.
- **Be conservative with pruning.** Only with positive evidence of irrelevance.
- **Distinguish gaps from limitations.** Gaps are improvement targets.
  Limitations are design decisions. Don't "fix" intentional limitations.
- **Measure everything.** REM needs quantitative baselines to evaluate patches.
