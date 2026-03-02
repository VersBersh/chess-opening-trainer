# CT-41: Implementation Notes

## Files Modified

- **`src/lib/widgets/repertoire_card.dart`** — Replaced `Wrap` layout with `Column(crossAxisAlignment: CrossAxisAlignment.stretch)`. Added `SizedBox(height: 8)` spacers between buttons. Applied `minimumSize: Size(double.infinity, 48)` to all three buttons. Merged the conditional `backgroundColor` into a single `FilledButton.styleFrom(...)` call that always sets `minimumSize` and conditionally sets `backgroundColor`.

- **`src/lib/widgets/home_empty_state.dart`** — Added `FilledButton.styleFrom(minimumSize: Size(double.infinity, 48))` to the empty-state button. Wrapped the button in `Padding(padding: EdgeInsets.symmetric(horizontal: 32))` to match the text padding above it.

## Deviations from Plan

None. All steps were implemented exactly as specified.

## Follow-up Work

None discovered during implementation.
