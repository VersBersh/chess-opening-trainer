- **Verdict** — `Needs Fixes`

- **Progress**
  - [x] **Step 1**: Pass loop index to `_MovePill` as `pillIndex` — **Done**
  - [ ] **Step 2**: Add `_semanticLabel` + wrap pill with `Semantics` — **Partially done**
  - [x] **Step 3**: Add semantic label to empty-state placeholder — **Done**
  - [ ] **Step 4**: Add semantics tests per plan (`ensureSemantics` + selected flag check approach) — **Partially done**

- **Issues**
  1. **Critical**: `excludeSemantics: true` on pill `Semantics` can suppress child gesture semantics, potentially removing the tap action from assistive tech.
     - File: [move_pills_widget.dart](/C:/code/misc/chess-trainer-8/src/lib/widgets/move_pills_widget.dart#L225)
     - Why: The parent `Semantics` node is now authoritative, but it does not provide an `onTap` semantic action. With descendants excluded, the `GestureDetector` semantics may not contribute tap behavior.
     - Fix: Remove `excludeSemantics: true` from the wrapper. Keep `ExcludeSemantics` only on the positioned label text as in the plan.

  2. **Major**: Selected-state test deviates from planned/stable assertion style and doesn’t verify via `SemanticsFlag.isSelected`.
     - File: [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart#L388)
     - Why: Plan explicitly called for `hasFlag(SemanticsFlag.isSelected)` to avoid version-fragile API usage. Current assertion uses `flagsCollection.isSelected`.
     - Fix: Replace with:
       - `expect(selectedNode.hasFlag(SemanticsFlag.isSelected), isTrue);`
       - `expect(unselectedNode.hasFlag(SemanticsFlag.isSelected), isFalse);`

  3. **Minor**: Semantics handles are disposed manually instead of via `addTearDown`, so cleanup is skipped if an assertion fails early.
     - Files:
       - [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart#L356)
       - [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart#L379)
       - [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart#L398)
     - Why: Plan required `addTearDown(handle.dispose)` for robust semantics-tree lifecycle management.
     - Fix: Immediately after `ensureSemantics()`, call `addTearDown(handle.dispose);` and remove explicit `handle.dispose()` lines.

