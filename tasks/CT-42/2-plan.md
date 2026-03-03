# CT-42 Plan: Unify pill colors (saved and unsaved look identical)

## Goal

Remove the visual distinction between saved and unsaved move pills so all pills render with the same background, text, and border colors regardless of save state.

## Steps

### 1. Remove `unsavedColor` from `PillTheme` and rename `savedColor` to `pillColor`

**File:** `src/lib/theme/pill_theme.dart`

- Remove the `unsavedColor` field entirely.
- Rename `savedColor` to `pillColor` (aligns with the `pillColor` token name in `design/ui-guidelines.md`).
- Rename `textOnSavedColor` to `textOnPillColor` (no longer specific to saved pills).
- Update the `PillTheme` constructor: remove the `unsavedColor` parameter, rename the others.
- Update `PillTheme.light()`: remove the `unsavedColor` assignment, rename `savedColor` to `pillColor` (keep the same `0xFF5B8FDB` value), rename `textOnSavedColor` to `textOnPillColor`.
- Update `PillTheme.dark()`: same removals and renames (keep the same `0xFF3A6BB5` value for `pillColor`, `0xFFE0E0E0` for `textOnPillColor`).
- Update `copyWith`: remove `unsavedColor` parameter, rename others.
- Update `lerp`: remove `unsavedColor` lerp, rename others.

### 2. Simplify `_MovePill.build` color logic to two cases (focused / unfocused)

**File:** `src/lib/widgets/move_pills_widget.dart`

- In the `pillTheme != null` branch, collapse the four-way `isSaved x isFocused` matrix into two cases:
  - **Focused:** `background = pillTheme.pillColor`, `textColor = pillTheme.textOnPillColor`, `borderColor = pillTheme.focusedBorderColor`, `borderWidth = 2`.
  - **Unfocused:** `background = pillTheme.pillColor`, `textColor = pillTheme.textOnPillColor`, `borderColor = pillTheme.pillColor`, `borderWidth = 1`.
- In the `pillTheme == null` fallback branch, similarly collapse to two cases:
  - **Focused:** use `colorScheme.primaryContainer` / `onPrimaryContainer` / `primary` / width 2.
  - **Unfocused:** use `colorScheme.surfaceContainerHighest` / `onSurface` / `outline` / width 1.
- The `data.isSaved` flag is no longer read for any color/styling decision in this widget.

**Depends on:** Step 1 (new property names).

### 3. Update `PillTheme` registration in `main.dart`

**File:** `src/lib/main.dart`

No code changes needed beyond what the constructor rename in step 1 requires. Since the named constructors `PillTheme.light()` and `PillTheme.dark()` are used directly, the registration call sites (`PillTheme.light()` and `PillTheme.dark()`) remain the same -- they just produce objects without `unsavedColor`.

**Depends on:** Step 1.

### 4. Update widget tests

**File:** `src/test/widgets/move_pills_widget_test.dart`

- Update the `_testPillTheme` constant: remove `unsavedColor`, rename `savedColor` to `pillColor`, rename `textOnSavedColor` to `textOnPillColor` (if explicitly set).
- **Test "focused saved pill has savedColor background":** rename to "focused pill has pillColor background". Keep the assertion but reference `_testPillTheme.pillColor` instead of `_testPillTheme.savedColor`.
- **Test "focused unsaved pill has unsavedColor background":** change to assert `_testPillTheme.pillColor` instead of `_testPillTheme.unsavedColor`. Rename the test to "focused unsaved pill has pillColor background" (or merge with the saved variant).
- **Test "saved vs unsaved pills have different styling":** **Rewrite** this test to assert that saved and unsaved pills have the **same** background color (`pillColor`) and the same border color. Change the `isNot` expectation to an equality expectation.
- **Test "renders without PillTheme extension (fallback)":** Keep as-is; it tests fallback coloring which still works (the fallback path uses two cases now, and the focused-saved path uses `primaryContainer`).

**Depends on:** Steps 1 and 2.

### 5. Verify controller and screen are unaffected

**Files:** `src/lib/controllers/add_line_controller.dart`, `src/lib/screens/add_line_screen.dart`

No changes needed. These files use `isSaved` for:
- Building `MovePillData` with the correct flag (controller) -- still needed for non-styling logic.
- Branching safety checks (`_allPillsSavedAfter`, `canBranch`) -- unchanged.
- Label editor gating in `_onPillTapped` (screen) -- unchanged.

This is a verification step, not a code change.

**Depends on:** Steps 1-4.

### 6. Run tests

Run `flutter test` in the `src/` directory to confirm all tests pass, including the updated pill widget tests and the unmodified controller tests.

**Depends on:** Steps 1-4.

## Risks / Open Questions

1. **Semantic label still says "saved" vs "new":** The `_semanticLabel` getter in `_MovePill` produces `"Move N: SAN, saved"` or `"Move N: SAN, new"`. The task says to stop using `isSaved` for **styling**, but the semantic label is an accessibility concern, not styling. The test `'pills have correct semantic labels'` asserts this distinction. **Decision needed:** Should the semantic label also be unified (e.g., always say just "Move N: SAN"), or should it continue distinguishing saved/new for screen reader users? The current plan leaves it as-is since the task scope is visual styling only.

2. **Fallback colorScheme path:** The fallback (no `PillTheme` registered) currently has four branches. Collapsing to two means the unsaved fallback colors change. This only affects tests that explicitly omit `PillTheme`; in production, `PillTheme` is always registered. The existing fallback test only checks the focused-saved case, so it should still pass.

3. **Renaming `savedColor` to `pillColor`:** This is a slightly broader rename than strictly necessary (we could instead just set `unsavedColor = savedColor`). However, the rename aligns with the `pillColor` token name in `design/ui-guidelines.md` and is cleaner long-term. The trade-off is more files touched. If the rename feels risky, an alternative is to keep `savedColor` and simply remove `unsavedColor`, using `savedColor` everywhere.
