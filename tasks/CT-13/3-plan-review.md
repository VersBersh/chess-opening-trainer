**Verdict** — Needs Revision

**Issues**
1. **Major (Step 1): Replacing `ChoiceChip` with `GestureDetector` + `Container` is unnecessary and increases regression risk.**  
   The codebase is already on Material 3, and Flutter’s `ChoiceChip` supports `showCheckmark` (see Flutter source `choice_chip.dart`) so the layout shift can be removed without replacing the component. Full replacement drops built-in chip behavior and diverges from Material theming patterns.  
   **Suggested fix:** Keep `ChoiceChip`, set `showCheckmark: false`, and style selected/unselected visuals via chip properties (`side`, `color`/`selectedColor`, `labelStyle`, optional `shape`) to get a non-shifting indicator with minimal change.

2. **Major (Step 1 + Risks): Accessibility impact is understated.**  
   The plan marks accessibility as “nice-to-have,” but replacing `ChoiceChip` with `GestureDetector` removes built-in semantics, focus/keyboard behavior, and standard tap target handling. Also, proposed `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)` does not guarantee a 48dp minimum touch target.  
   **Suggested fix:** Treat accessibility as required. Prefer retaining `ChoiceChip`; if custom UI is still chosen, use `Semantics` + `InkWell`/`FocusableActionDetector` + enforced min size (`ConstrainedBox(minHeight: 48)`).

3. **Minor (Step 2): Verification scope is too narrow and manual-only.**  
   The plan only calls for visual checks of board/piece pickers. It does not verify interaction behavior that could regress with the proposed widget swap.  
   **Suggested fix:** Add verification for tap behavior, keyboard/focus behavior, and semantics; ideally include/update a widget test covering piece-set selection and “no checkmark layout jump” behavior.