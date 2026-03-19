---
name: drift
description: "Stage N1. Stochastic scanning of past conversations to gather raw memory fragments. Broad, unfocused, deliberately noisy. The only stage that touches conversation history directly."
context: fork
user-invocable: false
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Drift — Stage N1

The hypnagogic scan. Fast, cheap, broad, noisy. ~5% of cycle time.

Drift is the only stage that directly searches past conversations. All
downstream stages work exclusively with drift's output.

## Inputs

From orchestrator: `target_skill`, `scan_depth` (default 10),
`recency_bias` (0-1, default 0.7), `randomness` (0-1, default 0.4),
`cycle_number` (1-indexed).

## Procedure

### 1. Extract Search Terms

Read the target SKILL.md. Extract:
- Skill name and description keywords
- File types it handles (.docx, .xlsx, etc.)
- Domain terms (presentation, spreadsheet, formatting)
- Action verbs specific to the skill

Build a keyword pool of 10-20 terms ranked by specificity.

### 2. Sample Conversations

Use `conversation_search` and `recent_chats` tools. Strategy varies
by cycle:

| Cycle | Recency Bias | Randomness | Scan Depth |
|-------|-------------|------------|------------|
| 1 | 0.8 | 0.3 | 8 |
| 2 | 0.5 | 0.5 | 10 |
| 3 | 0.3 | 0.7 | 12 |
| 4+ | 0.2 | 0.8 | 15 |

Early cycles: mostly `recent_chats`. Later: mostly `conversation_search`
with random keywords from the less-specific end of the pool. Include
cross-domain terms in later cycles.

### 3. Extract Fragments

From each result, extract 1-3 sentence fragments capturing:
- What the user asked for
- What tools/skills were involved
- Friction signals (corrections, rephrasing, frustration)
- Unusual elements (unexpected file types, edge requirements)

Do NOT reproduce conversation content — summarize the essence.

**Fragment format** (YAML):
```yaml
- id: f001
  source: recent_chats | conversation_search
  recency: recent | mid | old
  relevance: direct | adjacent | tangential
  content: "User requested Word doc with mixed English/Arabic, bidirectional TOC"
  friction: true
  friction_signal: "Corrected RTL formatting twice"
  tags: [docx, rtl, toc, multilingual]
  synthetic: false
```

### 4. Inject Noise

Add 1-3 synthetic fragments — deliberately tangential or surreal:
- **Domain mashup**: Combine skill domain with random unrelated domain
- **Scale distortion**: Warp a quantity from a real fragment to extremes
- **Inversion**: Flip an assumption from a real fragment

Tag all as `synthetic: true`.

### 5. Output Fragment Bag

```yaml
fragment_bag:
  target_skill: /path/to/SKILL.md
  cycle_number: 1
  total_fragments: 14
  sources: {recent_chats: 7, conversation_search: 4, synthetic: 3}
  fragments: [...]
```

## Behavioral Rules

- **Be fast.** Don't over-analyze. If vaguely relevant, include it.
- **Be broad.** Include tangential material. Cross-pollination needs it.
- **Be noisy.** Synthetic fragments are not optional.
- **Don't judge.** Filtering is N2's job, not yours.

## Edge Cases

- No conversations found: Generate 5-8 fully synthetic fragments from
  the skill's documented scope. Dreams don't require real memories.
- Very few results (<3): Supplement with synthetic to minimum bag of 5.
