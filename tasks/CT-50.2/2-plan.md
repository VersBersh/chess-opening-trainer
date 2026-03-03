# CT-50.2: Plan

## Goal

Deliver stable, anchored filter suggestions for Free Practice that keep the input visible and choose overlay direction based on available space, capped to fit within that space.

## Steps

1. Review current filter widget/overlay composition in `drill_screen.dart`.
   - The filter is `_DrillFilterAutocomplete`, a `StatefulWidget` wrapping `RawAutocomplete<String>`.
   - The `optionsViewBuilder` currently emits an `Align(Alignment.topLeft, ...)` with `ConstrainedBox(maxHeight: 200)` — always opening downward with a hardcoded height cap.
   - The filter box is rendered in two screen states: active drill (via `_buildDrillScaffold`) and pass-complete (via `_buildPassComplete`). Both paths call `_buildFilterBox`.

2. Measure usable viewport space above and below the input anchor.
   - Obtain the render box of the `TextField` (or its parent anchor) using `context.findRenderObject()` cast to `RenderBox`, then call `localToGlobal(Offset.zero)` to get the field's top-left in global coordinates.
   - Compute usable screen height as:
     ```
     usableHeight = MediaQuery.of(context).size.height
                    - MediaQuery.of(context).viewInsets.bottom
                    - MediaQuery.of(context).padding.bottom
     ```
     This correctly excludes the software keyboard and safe-area inset from the available space calculation.
   - `spaceBelow = usableHeight - (fieldOrigin.dy + fieldHeight)`
   - `spaceAbove = fieldOrigin.dy - MediaQuery.of(context).padding.top`
   - The available height for the dropdown on a given side is `min(maxDesiredHeight, spaceAbove_or_spaceBelow)`, where `maxDesiredHeight` can be a constant (e.g. 200 logical pixels).

3. Implement direction strategy inside `optionsViewBuilder`.
   - Prefer downward if `spaceBelow >= min(maxDesiredHeight, 80)` (80 px being a practical minimum for a useful list).
   - Otherwise open upward, capping to `spaceAbove` if that is smaller than `maxDesiredHeight`.
   - If neither side has 80 px, fall back to upward and cap to `spaceAbove` to avoid total occlusion.
   - Pass the computed `dropdownHeight` and `openUpward` flag into `optionsViewBuilder` via `setState` in a `LayoutBuilder` or by computing from a `GlobalKey` attached to the `fieldViewBuilder` output.

4. Adjust list constraints inside `optionsViewBuilder`; keep `RawAutocomplete` plumbing unchanged.
   - Do NOT replace `RawAutocomplete` or introduce a custom overlay. The existing widget handles focus, keyboard routing, and selection callbacks correctly.
   - The only change is in `optionsViewBuilder`: replace the hardcoded `BoxConstraints(maxHeight: 200)` with the dynamically computed height, and change the `Align` alignment from `Alignment.topLeft` (downward) to `Alignment.bottomLeft` (upward) when `openUpward` is true.
   - No changes to `optionsBuilder`, `onSelected`, `fieldViewBuilder`, or the controller/filter state.

5. Manually verify behavior across the following scenarios:
   - **Small screen, keyboard open** (e.g., phone portrait): the dropdown should open upward and be capped to the space above the field, not overlapping the keyboard.
   - **Large screen, keyboard absent** (e.g., tablet or wide layout): the dropdown should open downward and use up to `maxDesiredHeight`.
   - **Active drill state** (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillFilterNoResults`): filter is at the bottom of the column layout; verify dropdown direction and clipping.
   - **Pass-complete state** (`DrillPassComplete`): filter is rendered inside a centered `Column` with less surrounding structure; verify the same direction logic applies correctly in this layout context.
   - In all cases: the typed text in the `TextField` must remain fully visible when the dropdown is open.

## Non-Goals

- No changes to filter matching logic.
- No redesign of drill/free-practice screen structure.
- No compile/test execution as part of this planning task set.

## Risks

- Keyboard insets and bottom controls may compete for vertical space. This is addressed explicitly in Step 2 by subtracting `viewInsets.bottom` and `padding.bottom` before computing `spaceBelow`.
- Overlay clipping can vary across platforms if anchor math is brittle. Using `RenderBox.localToGlobal` inside `optionsViewBuilder`'s `context` is more reliable than measuring from a parent widget's context, because Flutter places the overlay relative to the field's own render position.
- The `GlobalKey` or measurement approach must not cause unnecessary rebuilds; prefer reading the render box once per options-open event rather than on every frame.
- `DrillPassComplete` renders the filter inside a scrollable centered `Column`. The global coordinate measurement still works here because `localToGlobal` is screen-relative, but the tester should confirm the pass-complete layout is included in manual verification (see Step 5).
- Review note: Issue 3 in the plan review flagged that the previous Step 4 wording was too vague and risked an overlay rewrite. The revised Step 4 above explicitly preserves `RawAutocomplete` and scopes the change to `optionsViewBuilder` constraints and `Align` alignment only.
