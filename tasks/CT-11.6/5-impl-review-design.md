- **Verdict** — `Needs Fixes`
- **Issues**
1. **Major — Hidden Semantic Coupling / Open-Closed**  
   [move_pills_widget.dart](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_pills_widget.dart#L10), [move_pills_widget.dart](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_pills_widget.dart#L166) hard-code `_kPillWidth = 66` based on an assumed default font/rendering profile. This couples layout correctness to current typography, platform font metrics, and text scaling. Any future typography/theme/accessibility change can silently break pill content fit.  
   Why it matters: the widget is not robustly extensible; style-level changes force code edits in this module, and large text scale users are at risk of overflow/clipping-like behavior.  
   Suggested fix: move width into a style token (e.g., `PillTheme`/design token) and compute or enforce fit with text scale in mind (at minimum add a text-scale regression test and document supported bounds; ideally derive width from measured target SAN + padding/border or use a resilient layout strategy such as constrained min width plus adaptive text handling).

2. **Minor — Clean Code (File Size / SRP in tests)**  
   [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-3/src/test/widgets/move_pills_widget_test.dart#L1) is **353 lines** after this change, exceeding the 300-line smell threshold.  
   Why it matters: this test file is becoming a broad “everything bagel” spec, which increases maintenance friction and weakens test intent locality.  
   Suggested fix: split into focused test files/groups (e.g., `move_pills_rendering_test.dart`, `move_pills_interaction_test.dart`, `move_pills_layout_test.dart`) with shared helpers extracted to a local test utility.