# CT-58: Discovered Tasks

## 1. Add `copyWith` to `AddLineState`

- **Suggested ID:** CT-59
- **Title:** Add `copyWith` to `AddLineState` to reduce field-threading brittleness
- **Description:** `AddLineState` has no `copyWith` method, so every mutation site must manually pass through all fields. Adding a new field (like `showHintArrows`) requires updating ~10 construction sites. A `copyWith` method would make state mutations safer and more concise.
- **Why discovered:** The design review flagged that threading `showHintArrows` through every `AddLineState(...)` construction site is brittle and violates open/closed principle. This is a pre-existing architectural issue that CT-58 exacerbated.

## 2. Extract arrow generation into a shared service

- **Suggested ID:** CT-60
- **Title:** Extract arrow generation logic from controllers into a shared service
- **Description:** Both `RepertoireBrowserController.getChildArrows()` and `AddLineController.getHintArrows()` build `Arrow`/`Shape` objects from `RepertoireTreeCache` data. The design review flagged that controllers importing `dart:ui` and `chessground` types mixes presentation concerns into business logic. A shared service could return domain descriptors (from/to/kind) and let the screen or an adapter map them to `Arrow`/`Color`.
- **Why discovered:** The design review flagged SRP and dependency inversion violations in the controller's arrow-generation method, and noted duplication with the browser controller's existing arrow logic.
