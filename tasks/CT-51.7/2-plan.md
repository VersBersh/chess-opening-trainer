# CT-51.7: Plan

## Goal

Remove the variable-height aggregate name banner from above the board in `AddLineScreen._buildContent` and replace it with a reserved-height label slot below the board.

## Steps

### Step 1 — Remove the conditional banner above the board

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildContent`, delete the entire `if (displayName.isNotEmpty) Container(...)` block (lines 381–398). This is the offending variable-height widget that shifts the board.

After this step, the column's first child will be the `SizedBox(height: kBoardFrameTopGap)` spacer, directly followed by the board — which is correct.

**Depends on:** nothing.

---

### Step 2 — Add a reserved-height aggregate name label slot below the board

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildContent`, insert a fixed-height label widget immediately after the `ConstrainedBox`/board widget and before `MovePillsWidget`. Follow the pattern established by `kLineLabelHeight` and `kLineLabelLeftInset`:

```dart
// Aggregate display name — reserved-height slot, always present.
SizedBox(
  height: kLineLabelHeight,
  width: double.infinity,
  child: displayName.isNotEmpty
      ? Padding(
          padding: const EdgeInsets.only(
            left: kLineLabelLeftInset,
            top: 4,
            bottom: 4,
          ),
          child: Text(
            displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )
      : null,
),
```

The `SizedBox` always reserves 32 dp regardless of whether `displayName` is empty, so the board position is stable.

**Depends on:** Step 1 (for correctness, but Steps 1 and 2 can be done together in one edit).

---

## Risks / Open Questions

1. **`titleSmall` vs `titleMedium`:** The old banner used `titleSmall`; the new slot uses `titleMedium` (matching `kLineLabelHeight = 32dp` which is sized for titleMedium). This is a deliberate alignment with the sizing constant's documented purpose (see `spacing.dart` comment).

2. **`kBoardFrameTopGap` stays:** The existing `SizedBox(height: kBoardFrameTopGap)` (line 400) is the correct top gap between app bar and board. It must remain. Only the conditional banner above it is removed.

3. **No controller changes needed.** `aggregateDisplayName` is already on `AddLineState`.
