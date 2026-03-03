**Verdict** — `Needs Revision`

**Issues**
1. **Major — Step 2 (layout strategy is still ambiguous and can violate spec constraints)**  
   The plan leaves two alternative implementations open (`per-pill vertical stack` vs `row item with known height budget`) without committing to one that guarantees stable wrapping. In the current code, all pills are fixed-width (`_kPillWidth`) and wrapped by `Wrap`; introducing mixed item heights per row can still cause visual drift and inconsistent row rhythm (already noted in Risks).  
   **Suggested fix:** Commit in the plan to a single approach: make each wrap child a fixed-size vertical item that always reserves a label slot (even when label is null), so every pill in a row has identical height and alignment.

2. **Major — Step 3 (does not explicitly address horizontal label collisions)**  
   Current overlap is not only vertical: labels are currently `Positioned` with `TextOverflow.visible` and no width constraint, so long labels can intrude into adjacent pills/labels. “Rework run spacing” alone will not fix that.  
   **Suggested fix:** Add an explicit sub-step to constrain label width to pill width (or a fixed max width tied to `_kPillWidth`) and use non-visible overflow behavior (`ellipsis`/`fade`/clip) with consistent alignment.

3. **Minor — Missing explicit check against parent layout constraints in `add_line_screen.dart`**  
   `1-context.md` marks `add_line_screen.dart` as relevant for width/placement constraints, but the plan does not include a concrete verification step for how the revised pill item height interacts with the `SingleChildScrollView` column and action-bar spacing on narrow screens.  
   **Suggested fix:** Add a step to validate the revised `MovePillsWidget` inside `AddLineScreen` at mobile widths (dense sequences) to ensure no new clipping/crowding regressions in surrounding sections.