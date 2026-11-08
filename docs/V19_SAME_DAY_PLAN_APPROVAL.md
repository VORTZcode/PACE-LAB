# Same-day adoption of previously generated pending weekly plan

The current pending 9–15 November 2026 plan was generated the previous day, then remained stored past midnight. The validation entry point in `PaceLibrary.acceptCoachDraft` re-used the rule `first date == tomorrow` which was meant for newly generated drafts. On 9 November this falsely rejected a correctly dated and still current seven-day plan.

Two distinct validation policies now apply:
- `.generatedTomorrow`: retained as default in AI draft extraction. Generation must propose seven consecutive days beginning the next day.
- `.approveTodayOrTomorrow`: only selected by explicit user confirmation in `PaceLibrary.acceptCoachDraft`. Allows the pending plan to begin today or tomorrow, and still rejects plans beginning yesterday or after tomorrow. Other session, meal, calorie and safety checks remain.

No pending plan or HealthKit data are changed. Installing over the current app preserves user history; no plan is adopted automatically.
