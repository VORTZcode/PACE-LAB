# PACE-LAB V10 — cycle planning, not a claim of guaranteed performance

## Implemented and verified

- Explicit four-phase local planning context derived from the last four seven-day windows, usable RPE/pain feedback, and evaluated prior plans.
- Previous accepted-plan rationale persisted on-device for future plan generation (legacy plans decode with missing rationale).
- Coach's plan generation receives the local phase with quality caveats and must justify changing stimulus.
- Pending proposal screen displays the observed phase and feedback coverage.
- Independent arithmetic checks for nutrition claims remain active.
- HealthKit permissions and OpenAI sharing consent remain separate; existing personal data is preserved.

## Limitations requiring future work, not falsely marketed as complete

- Four-week evidence is descriptive, not a validated fitness, injury-risk, or readiness estimate.
- HealthKit workout history by itself cannot establish adaptation to a training block; controlled comparable performances, subjective feedback, and repeat observations are needed.
- No deterministic physiological optimizer or scientifically validated prescription engine is installed.
- Current LLM generates plans with guardrails; in-app phase assessment does not automatically validate intensity or prove session duration feasibility.
- Workouts and AI sessions in the background are still best-effort. Reliable generation while the iPhone is suspended requires a backend job and queued result retrieval.
- No long-term prospective outcomes trial, real swipe/typing interaction test, or independent exercise professional validation completed.
- Before shipping more automated decisions, add multi-week scenario-based tests, an explainable typed prescription schema, and recovery-aware optional-session semantics.

## Decision integrity

Never silently accept a draft. A rejected draft remains pending for inspection; accepted plans and actual HealthKit observations are kept separately. Never infer unrecorded symptoms or fitness from a missing sample.
