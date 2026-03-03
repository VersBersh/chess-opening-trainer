- **Verdict** — `Approved with Notes`
- **Issues**
1. **Minor — Hidden Coupling / Primitive Obsession** ([move_pills_widget.dart](/C:/code/misc/chess-trainer-2/src/lib/widgets/move_pills_widget.dart):17, [move_pills_widget.dart](/C:/code/misc/chess-trainer-2/src/lib/widgets/move_pills_widget.dart):192, [move_pills_widget.dart](/C:/code/misc/chess-trainer-2/src/lib/widgets/move_pills_widget.dart):197)  
`_kLabelSlotHeight = 14` is tightly coupled to `fontSize: 10` and assumes a specific text scale. If text scaling increases (accessibility settings), the fixed slot can clip glyphs while still enforcing single-line ellipsis.  
Why it matters: layout correctness now depends on implicit typography assumptions rather than an explicit constraint model.  
Suggested fix: derive slot height from the effective text style (or reserve a safer min height based on text scale), and document that the slot height tracks label typography.

The core refactor is otherwise strong: it simplifies layout responsibilities, removes overlap-prone out-of-flow painting, keeps tap behavior isolated to the pill body, and improves long-label handling via width constraint + ellipsis. No changed code file in scope exceeds 300 lines.