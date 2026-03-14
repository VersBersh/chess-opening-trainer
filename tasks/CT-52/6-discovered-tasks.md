# CT-52 Discovered Tasks

## 1. Reduce kLineLabelLeftInset to match board margin

- **Suggested ID:** CT-53
- **Title:** Align line-label left inset with board horizontal margin
- **Description:** With board margins now at 4dp, the 16dp `kLineLabelLeftInset` looks visually misaligned. Reduce to `kBoardHorizontalInset` (4dp) for consistency.
- **Why discovered:** The near-zero board margin makes the 16dp label inset visually disproportionate.

## 2. Move Add Line display-name banner below the board

- **Suggested ID:** CT-54
- **Title:** Move Add Line display-name banner below the board (spec compliance)
- **Description:** The Add Line narrow layout renders a dynamic `aggregateDisplayName` banner above the board, violating the "no dynamic content above the board" rule in `board-layout-consistency.md`. Move it below the board or into the app bar subtitle.
- **Why discovered:** The wide layout was fixed during CT-52, but the narrow layout still has the banner above the board. This is a pre-existing issue not introduced by CT-52.

## 3. Extract shared board frame widget

- **Suggested ID:** CT-55
- **Title:** Extract shared board frame widget to reduce screen file sizes
- **Description:** `add_line_screen.dart` (690 lines) and `drill_screen.dart` (560 lines) both contain duplicate board framing logic (Padding + ConstrainedBox + AspectRatio). Extract a shared `BoardFrame` widget that encapsulates responsive sizing (narrow and wide) to reduce duplication and enforce the consistency contract structurally.
- **Why discovered:** Code review flagged file sizes and duplicated board framing code across screens.
