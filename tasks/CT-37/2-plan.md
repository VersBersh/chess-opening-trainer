# CT-37: Implementation Plan

## Goal

Replace the technical "parity mismatch" warning with plain-language messaging and softer styling.

## Steps

### Step 1: Update warning text in `add_line_screen.dart`

File: `src/lib/screens/add_line_screen.dart`, method `_buildParityWarning()` (lines 455-514)

- **Change title** (line 480) from `'Line parity mismatch'` to a dynamic plain-language message based on `boardOrientation`:
  - White: `"Lines for white should end on a white move"`
  - Black: `"Lines for black should end on a black move"`
  - Use `currentSide` (already computed at line 459-460) to build: `'Lines for $currentSide should end on a $currentSide move'`

- **Simplify body text** (lines 498-501): Replace the technical explanation with a short hint: `'Try adding one more move, or flip the board.'`

- **Keep** the "Flip and confirm as $expectedSide" button text unchanged — it already uses plain language.

### Step 2: Change warning styling from error-red to tertiary

File: `src/lib/screens/add_line_screen.dart`, same method

- Replace `colorScheme.errorContainer` (line 466) with `colorScheme.tertiaryContainer`
- Replace all `colorScheme.onErrorContainer` references (lines 476, 483, 490, 501, 507) with `colorScheme.onTertiaryContainer`
- Change icon from `Icons.warning_amber_rounded` to `Icons.info_outline` to further reduce alarm

This uses the existing M3 palette (already used for move pill highlights) — no custom colors needed.

### Step 3: Update widget tests

File: `src/test/screens/add_line_screen_test.dart`

- Replace all `find.text('Line parity mismatch')` assertions with the new dynamic text. In the test helper `triggerParityMismatchWarning`, the board is white-oriented, so expected text is `'Lines for White should end on a White move'`.
- Update any `find.textContaining` calls that reference old body text.
- Update the `triggerParityMismatchWarning` doc comment if it mentions "parity mismatch".

### Step 4: Verify no other user-facing occurrences

Grep `lib/` for any user-facing strings containing "parity mismatch" (case-insensitive). Internal type names (`ParityMismatch`, `ConfirmParityMismatch`) are code identifiers and do not need changing.

## Risks / Open Questions

1. **Exact wording**: Task says "something like". The plan uses `"Lines for $currentSide should end on a $currentSide move"`. Team might prefer different phrasing.
2. **Tertiary color tone**: With indigo seed, `tertiaryContainer` produces a soft pinkish/mauve. Should be noticeably softer than error-red but still distinct. If team prefers amber/yellow, would need custom color.
3. **Test count**: Multiple test assertions reference the old string. All must be updated or tests will fail — straightforward but must be thorough.
