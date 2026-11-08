# PACE-LAB V18 — first structural product redesign

This version responds to the athlete's feedback that Volt Lime alone was a reskin, not a Strava-class product redesign. It changes major information architectures and actionable compositions without modifying sports data, accepted plans or HealthKit consent.

## Shipped native screens

1. **Today:** former decorative RUN BEYOND headline replaced with a large, navigable seven-day performance stage with real daily distance bars, real run count, real elapsed workout duration, and an action opening the weekly activity analysis. Next workout becomes a distinct 'À toi de jouer' section, followed by last activity, Coach and other metrics.
2. **Activities:** last run's feature card is rebuilt as an editorial sports record with dominant recorded distance, date, measured average HR if available, moving pace from HealthKit duration/distance, workout duration, and access to route/Flyover through workout details. Existing filters, year and list remain functional.
3. **Progression:** year overview rebuilt as 12 real monthly training volume bars and an oversized numerical performance summary, preceding original scientific evidence and detailed charts.
4. **Programme:** quick seven-day horizontally scrollable workout cards link to each day's genuine detail, distinguish manually confirmed session completions visually, and preserve existing evidence-linking and the full workout list.
5. **Coach:** measured seven-day run count and conditional plan pending status shown in an athletic header on Bilans/Programme tabs, without obstructing chat.
6. **Shared components:** opaque graphite card surfaces and subtle outlines replace the excessive all-over Liquid Glass; floating/interactive controls retain native effects.

## Validation and constraints

- Xcode compilation for signed physical iPhone: successful.
- Source contract checks V18, V17, coach V9–V11 and Flyover V15–V16: successful.
- Recorded GPS, HealthKit activity data, private medical data, accepted plans and current coach logic are unchanged.
- UI interaction visual QA still required on a physical iPhone; rendered simulator screenshots are not substitutes.
- Do not claim feature parity with Strava: live workout map cards, privacy-safe sharing, social layers, complete recording and comprehensive information architecture remain future work.
