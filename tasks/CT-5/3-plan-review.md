**Verdict** — `Needs Revision`

**Issues**
1. **Critical — Step 4 (`_handleLineComplete` quality switch)**
   The proposed `switch (result.quality)` snippet is not valid Dart as written because each `case` needs termination (`break`/`return`) and implicit fallthrough is not allowed. Also, in current code `completeCard()` returns `CardResult?` ([src/lib/services/drill_engine.dart](/C:/code/misc/chess-trainer-1/src/lib/services/drill_engine.dart)), so using `result.quality`/`result.updatedCard` without a null-safe guard is unsafe and will not type-check unless force-unwrapped.
   Fix: Use either `if/else` on `result?.quality`, or guard `if (result != null) { ... }` before quality/date accumulation and review-date access, with explicit handling for `null`.

2. **Major — Step 3 (session duration start point)**
   The plan says to initialize `_sessionStartTime` in `build()` after loading due cards. In current flow, `build()` performs repository I/O and tree construction before first card start ([src/lib/screens/drill_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart)), so this can include setup latency in “session duration,” which is not actual drill time.
   Fix: Set `_sessionStartTime` immediately before `_engine.startCard()` (or at first transition to `DrillCardStart`) so duration reflects active session time.

3. **Minor — Step 4/5 (next due date semantics)**
   The plan stores only `_earliestNextDue`, but acceptance text says to “collect `nextReviewDate` from each `CardResult.updatedCard`.” Single-date preview may be fine, but this is an interpretation, not guaranteed by spec.
   Fix: Clarify in plan that preview intentionally shows earliest next due date; alternatively collect all dates and derive preview from that set explicitly (e.g., earliest, or range).