<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

- Original statistics content lives in src/lib/exam-data.ts; course banks and calculated totals live in src/lib/exam-banks.ts, and grading rules in src/lib/grading.ts, so rendering and scoring always share the selected bank.
- ExamWorkspace owns a keyed ExamSession per selected bank; course changes reset answers, timer and local report state together to prevent grading stale answers against another course.
- AI calls go through the authenticated askAi server function (src/lib/ai.functions.ts); it enforces the free-tier limit server-side by counting generated_exams rows.
- Prices, platform fee and free-tier limits live in src/lib/fees.ts (tested in src/test/fees.test.ts); checkout amounts are always recomputed server-side in src/lib/payments.functions.ts.
- Payment state is written only by the webhook at src/routes/api/public/payments/webhook.ts; bookings/purchases rows are created pending by the checkout server function.
- Reward/streak/planner rules live in src/lib/rewards.ts (tested in src/test/rewards.test.ts); all feedback sounds/animations go through useRewards so the global sound/motion switches apply.
- Overwhelm state lives in PrefsProvider; every study timer must pause elapsed accumulation while calm is active, preserving answers and session state.
- XP inventory records spent XP separately from lifetime XP; buy_reward performs atomic, authenticated purchases so levels remain stable and simultaneous purchases cannot overspend.
- AI support surfaces share askAi and its server-enforced generation limit; structured chapter maps are validated before rendering, and browser voice/audio resources are created only in user actions and cleaned up.
- Final revision uses an explicit study_goals.test_at timestamp rather than guessing an exam time from a date-only goal.
- Launch library full text uses an anon column-scoped SELECT grant and published-document read policy; private uploads remain owner-only so opening reading never exposes private study files.
- Micro-learning derives course quizzes from exam-banks and chunks library readings and pasted own text (gap-fill quiz) locally in micro-learning.ts, so scoring stays shared and basic reading uses no AI generation.
- Guest planner goals use separate local device storage; signed-in goals remain owner-scoped Cloud records so public study tools do not weaken private data access.
- Pacing rules (micro-chunk sizes, hyperfocus reminder, sprint/forced-break day schedule) live in src/lib/pacing.ts (tested in src/test/pacing.test.ts) so all timers and readers share one rule; the forced-break overlay is portaled so it shows from any tab.
- Secondary header preferences and study tools share a settings popover; keep its content mounted while closed so moving controls never resets active timers or audio.
- Daily drops are deduplicated by owner and Stockholm date under the same profile lock as XP purchases; avatar equipment is validated against owned inventory through equip_avatar.
- Avatar identity uses owner-scoped avatar_equipment shared by header and studio; lifetime XP remains separate from inventory spending and defines titles/levels.
- Profile reward fields are not directly writable by authenticated clients; existing study XP awards use atomic add_study_xp with a fixed amount allowlist, while cosmetic avatar equipment uses ownership-checked RPCs.
- Community posts (tentabanken) award XP only via DB triggers (25 XP per post, max 3/day; +2 XP to author per unique like, likes can't be undone) so clients never write reward fields.
