- **Verdict** — `Needs Fixes`
- **Issues**
1. **Major — Hidden coupling / Encapsulation leak (`Data Structures`, `Clean Code: side effects`)**  
   [drill_screen.dart:188](C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:188), [drill_screen.dart:191](C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:191), [drill_screen.dart:477](C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:477) expose and store mutable collections directly (`Set<String>` / `List<String>`).  
   Why it matters: callers can mutate controller internals without going through `applyFilter`, creating hidden side effects and queue/UI divergence.  
   Suggested fix: return defensive/read-only views (`UnmodifiableSetView`, `UnmodifiableListView`) and copy inputs (`_selectedLabels = Set.of(labels)`).

2. **Major — Semantic coupling not enforced (`SOLID: SRP`, `Hidden Coupling: semantic/temporal`)**  
   [drill_screen.dart:476](C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:476) `applyFilter` has no guard for mode/invariants, while only UI currently prevents usage in non-free-practice ([drill_screen.dart:838](C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:838)).  
   Why it matters: behavior correctness depends on external call order/context (“only call from free-practice UI after full build”), which is not enforced by the controller API.  
   Suggested fix: add explicit guard(s) in `applyFilter` (for `arg.isExtraPractice`, engine/tree readiness) and fail fast or no-op with clear contract comments.

3. **Minor — File size / mixed abstraction levels (`Clean Code: file size`, `Embedded Design Principle`)**  
   [drill_screen.dart](C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart) is **1117 lines** and now includes config/state models, controller orchestration, scaffold rendering, and filter widget/autocomplete.  
   Why it matters: too many reasons to change in one module reduces architectural readability and makes extension/testing harder.  
   Suggested fix: split into focused units (for example `drill_controller.dart`, `drill_states.dart`, `drill_screen_view.dart`, `drill_filter_box.dart`).