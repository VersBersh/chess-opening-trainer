# CT-7.1 Discovered Tasks

## CT-7.6: Move Pills Accessibility Semantics

**Title:** Add accessibility semantics to MovePillsWidget

**Description:** Wrap each pill in a `Semantics` widget with descriptive labels (e.g., "Move 3: Nf3, saved") for screen reader support. Add semantic labels to the delete action as well.

**Why discovered:** Both code reviews flagged the absence of `Semantics` wrappers as a gap. The plan's Risk #5 identified this as a consideration but deferred it. It should be addressed before release.

## CT-7.7: Move Pills Auto-Scroll

**Title:** Auto-scroll move pills to keep focused pill visible

**Description:** When a pill is focused or a new pill is appended, the horizontal scroll view should auto-scroll to keep the relevant pill visible. This requires either the parent screen owning the `ScrollController` or making `MovePillsWidget` internally stateful for scroll mechanics only.

**Why discovered:** The original plan included auto-scroll (Step 4) but it was removed during plan review because it would make the widget stateful. The UX need remains -- for long lines, the focused pill may be off-screen. Best addressed in CT-7.2 where the parent screen can own the scroll controller.
