# CT-7.1 Plan

## Goal

Build a reusable, stateless horizontal move pills widget that displays a line as tappable SAN pills with focus highlighting, saved/unsaved visual distinction, optional label display, and delete-last-pill support.

## Steps

### 1. Define the `MovePillData` model class

**File:** `src/lib/widgets/move_pills_widget.dart` (new)

Create a simple data class that represents a single pill's display state. This decouples the widget from `RepertoireMove` and `BufferedMove`:

```dart
class MovePillData {
  final String san;
  final bool isSaved;
  final String? label;

  const MovePillData({
    required this.san,
    required this.isSaved,
    this.label,
  });
}
```

- `san` -- the move's Standard Algebraic Notation (e.g., "e4", "Nf3"), displayed as the pill text.
- `isSaved` -- `true` for moves that exist in the database (from `existingPath` + `followedMoves`), `false` for buffered/unsaved moves. Controls the visual styling of the pill.
- `label` -- the optional label text from `RepertoireMove.label`. Only saved moves can have labels. Displayed beneath the pill when non-null.

**Depends on:** Nothing.

### 2. Create the `MovePillsWidget` stateless widget

**File:** `src/lib/widgets/move_pills_widget.dart`

Create a `StatelessWidget` with the following constructor parameters:

```dart
class MovePillsWidget extends StatelessWidget {
  const MovePillsWidget({
    super.key,
    required this.pills,
    this.focusedIndex,
    required this.onPillTapped,
    this.onDeleteLast,
  });

  final List<MovePillData> pills;
  final int? focusedIndex;
  final void Function(int index) onPillTapped;
  final VoidCallback? onDeleteLast;
}
```

- `pills` -- the ordered list of pill data, one per ply. Index 0 is the first move.
- `focusedIndex` -- the index of the currently focused pill, or `null` if no pill is focused.
- `onPillTapped` -- callback invoked when a pill is tapped, with the tapped pill's index.
- `onDeleteLast` -- callback invoked when the delete action is triggered on the last pill. When `null`, the delete affordance is hidden (e.g., when there are no buffered moves to delete).

**Build method:**

Render a horizontal `SingleChildScrollView` containing a `Row` of pill widgets. Wrap the `SingleChildScrollView` in a `SizedBox` with a fixed height to constrain vertical space (pills + label area).

If `pills` is empty, render a `SizedBox.shrink()` or a subtle placeholder text (e.g., "Play a move to begin").

**Depends on:** Step 1.

### 3. Build the individual `_MovePill` private widget

**File:** `src/lib/widgets/move_pills_widget.dart`

Create a private stateless widget `_MovePill` that renders a single pill:

```dart
class _MovePill extends StatelessWidget {
  const _MovePill({
    required this.data,
    required this.isFocused,
    required this.isLast,
    required this.onTap,
    this.onDelete,
  });

  final MovePillData data;
  final bool isFocused;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
}
```

**Visual design using Material 3 color scheme:**

- **Saved + focused pill:** Background `colorScheme.primaryContainer`, text color `colorScheme.onPrimaryContainer`, border `colorScheme.primary` (2px). This matches the selection style used in `_MoveTreeNodeTile`.
- **Saved + unfocused pill:** Background `colorScheme.surfaceContainerHighest`, text color `colorScheme.onSurface`, border `colorScheme.outline` (1px).
- **Unsaved + focused pill:** Background `colorScheme.tertiaryContainer`, text color `colorScheme.onTertiaryContainer`, border `colorScheme.tertiary` (2px). Tertiary distinguishes unsaved from saved.
- **Unsaved + unfocused pill:** Background `colorScheme.surfaceContainerHighest` with reduced opacity (or a dashed-style border via `colorScheme.outlineVariant`), text color `colorScheme.onSurfaceVariant`. This subtly communicates the move is not yet persisted.

**Layout of each pill:**

```
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Pill container
    GestureDetector / InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: <background based on state>,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: <border color>, width: <1 or 2>),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.san, style: <styled text>),
            if (isLast && onDelete != null) ...[
              SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close, size: 14),
              ),
            ],
          ],
        ),
      ),
    ),
    // Label (if present)
    if (data.label != null)
      Transform.rotate(
        angle: -0.15,  // slight angle (~8.5 degrees) for compact fit
        child: Text(
          data.label!,
          style: TextStyle(fontSize: 10, color: colorScheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
  ],
)
```

Wrap each pill in a `Padding` with small horizontal margins (e.g., `EdgeInsets.only(right: 4)`).

**Delete affordance:** Only the last pill (`isLast: true`) shows the delete icon, and only when `onDelete` is non-null. The icon is small (14px) and positioned within the pill container next to the SAN text. Tapping it fires the `onDelete` callback without also firing `onTap` -- use a `GestureDetector` that stops propagation, or position it as a separate tap target within the pill's `Row`.

**Depends on:** Step 2.

### 4. Write widget tests for `MovePillsWidget`

**File:** `src/test/widgets/move_pills_widget_test.dart` (new)

Follow the test patterns from `move_tree_widget_test.dart`. Create a `buildTestApp` helper that wraps `MovePillsWidget` in `MaterialApp` + `Scaffold` + `SizedBox`.

**Test cases:**

- **Renders correct number of pills:** Provide a list of 5 `MovePillData` items. Verify 5 SAN texts are found.
- **Empty list shows no pills:** Provide an empty list. Verify no pill widgets are rendered (or a placeholder is shown).
- **Tapping a pill fires onPillTapped with correct index:** Provide 3 pills, tap the second pill's SAN text. Verify callback receives index 1.
- **Focused pill has distinct visual styling:** Provide 3 pills with `focusedIndex: 1`. Verify the focused pill's `Container` has the `primaryContainer` background color (for a saved pill) or `tertiaryContainer` (for an unsaved pill).
- **Saved vs. unsaved pills have different styling:** Provide 2 saved pills and 1 unsaved pill. Verify the unsaved pill has a visually distinct decoration (e.g., different background color or border style).
- **Label displayed beneath pill when present:** Provide a pill with `label: "Sicilian"`. Verify the label text is rendered.
- **No label when null:** Provide a pill with `label: null`. Verify no label text appears below it.
- **Delete icon visible on last pill only:** Provide 3 pills with `onDeleteLast` non-null. Verify the close icon appears only once (on the last pill).
- **Delete icon hidden when onDeleteLast is null:** Provide 3 pills with `onDeleteLast: null`. Verify no close icon is rendered.
- **Tapping delete icon fires onDeleteLast callback:** Provide 3 pills with `onDeleteLast` callback. Tap the close icon on the last pill. Verify the callback fires.
- **Tapping delete icon does not fire onPillTapped:** Tap the close icon. Verify `onPillTapped` was NOT called (only `onDeleteLast` was called).

**Depends on:** Steps 1-3.

### 5. Run tests and lint validation

Run `flutter test test/widgets/move_pills_widget_test.dart` to verify all widget tests pass. Run `flutter analyze` to verify the new file has no lint warnings or errors. Fix any issues before considering the task complete.

**Depends on:** Step 4.

## Risks / Open Questions

1. **Label angle value.** The spec says labels should be "vertically angled/slanted to fit the compact horizontal layout." The plan uses `Transform.rotate(angle: -0.15)` (approximately -8.5 degrees). This is a visual design choice that may need tuning during implementation. The angle should be small enough to remain readable but angled enough to save horizontal space for long labels.

2. **Delete affordance UX.** The plan places a small "x" icon inside the last pill. Alternatives include: a long-press gesture, a separate delete button outside the pill row, or a swipe-to-delete gesture. The inline icon is the most discoverable option. The icon must be large enough to tap reliably (minimum 24x24 touch target per Material guidelines) while being visually small. The implementing agent should ensure the `GestureDetector` for the delete icon has adequate padding for touch accuracy.

3. **Pill data transformation responsibility.** The `MovePillData` model is intentionally simple and decoupled from `RepertoireMove`/`BufferedMove`. The parent screen (CT-7.2) must transform the `LineEntryEngine`'s three lists (`existingPath`, `followedMoves`, `bufferedMoves`) into a single `List<MovePillData>`. This transformation is straightforward but must correctly map labels (only from `RepertoireMove` objects) and `isSaved` flags.

4. **Horizontal overflow with many pills.** For very long lines (30+ moves), the horizontal scroll view will contain many pills. This is handled naturally by `SingleChildScrollView` -- no virtualization is needed since pills are lightweight widgets and chess lines rarely exceed 40-50 plies. If performance becomes a concern, a `ListView.builder` with `scrollDirection: Axis.horizontal` can be substituted.

5. **Accessibility.** Each pill should have a semantic label for screen readers (e.g., "Move 5: Nf3, saved" or "Move 8: Bg5, unsaved"). This can be added via `Semantics` widget wrapping each pill. The plan does not detail this, but the implementing agent should consider it.

6. **Auto-scroll deferred.** The 1-context.md architecture notes mention auto-scrolling to keep the focused pill visible, but implementing this would require either making `MovePillsWidget` a `StatefulWidget` (for `ScrollController` + `GlobalKey` management + post-frame callbacks) or pushing scroll logic to the parent. Both approaches conflict with the simplicity goals of CT-7.1 and add lifecycle complexity (key synchronization, post-frame timing, potential for flaky tests). Auto-scroll is deferred entirely -- if needed, it can be added in CT-7.2 where the parent screen owns the scroll controller, or in a dedicated follow-up task.

7. **Review issue 3 (Step 6 was a no-op) -- addressed.** The original plan had a Step 6 "Export the widget" which was effectively a no-op since this codebase imports files directly and public classes are already exposed. That step has been replaced with Step 5 (run tests and lint), which provides concrete validation.
