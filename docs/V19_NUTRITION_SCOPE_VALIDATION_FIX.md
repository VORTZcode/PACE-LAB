# Fix: false nutrition validation blocker on pending weekly plan

The saved plan for 9–15 Nov 2026 lists 14 planned meals totaling 15,120 kcal, i.e. 2,160 kcal/day, and 1,045 g protein for the week. The evidence note correctly stated approximately 2,160 kcal/day and 150 g protein/day. The former over-broad weekly regex matched `repas proposés représentent en moyenne environ 2160 kcal` as an entire weekly energy total, falsely comparing it to all 14 meals and refusing plan adoption.

The checker now requires an explicit weekly scope for weekly comparisons. A separately scoped daily expression allows `N kcal et M g de protéines par jour`. This retains independently computed totals and guards against real weekly and daily contradictions. Tested Foundation/NSRegularExpression with original generic daily wording, known mismatched weekly totals and wrong daily totals. Existing plan remains in UserDefaults and is not adopted by the update.

This is arithmetic validation of proposed meals, not a proof of personalized energy requirements or meal nutrient-label accuracy. All other independent safety checks remain enabled.
