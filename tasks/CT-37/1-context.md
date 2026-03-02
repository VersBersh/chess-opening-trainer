# CT-37: Context

## Relevant Files

- **`src/lib/services/line_entry_engine.dart`** — Defines `ParityMismatch` result type (lines 50-54) with `expectedOrientation: Side`, and `validateParity()` (lines 193-204). Pure business logic.
- **`src/lib/controllers/add_line_controller.dart`** — Wraps engine; `confirmAndPersist()` returns `ConfirmParityMismatch` (lines 86-89) containing the mismatch to the UI layer.
- **`src/lib/screens/add_line_screen.dart`** — Renders warning in `_buildParityWarning()` (lines 455-514). Contains the user-facing "Line parity mismatch" title, body text, and error-red styling.
- **`src/test/screens/add_line_screen_test.dart`** — Widget tests asserting on `'Line parity mismatch'` text (~8+ occurrences) and "Flip and confirm as Black/White" button text.
- **`src/lib/main.dart`** — Defines `ColorScheme.fromSeed(seedColor: Colors.indigo)` which determines available M3 color tokens.

## Architecture

Three-layer architecture:

1. **LineEntryEngine** (service) — Pure logic. `validateParity(boardOrientation)` compares total ply parity against board orientation and returns `ParityMatch` or `ParityMismatch(expectedOrientation)`.
2. **AddLineController** — Wraps engine, manages `AddLineState`. On confirm, calls `validateParity()` and wraps mismatch into `ConfirmParityMismatch` for the UI.
3. **AddLineScreen** — Renders the parity warning as an inline container with title, body text, dismiss button, and "Flip and confirm" action. Uses `colorScheme.errorContainer` / `onErrorContainer` (dark red).

Key constraints:
- `ParityMismatch` type is internal API — not shown to users, doesn't need renaming.
- Warning text strings are asserted in widget tests — text changes must be synced with tests.
- App uses Material 3 `ColorScheme.fromSeed(seedColor: Colors.indigo)`. `tertiaryContainer` is already used elsewhere (move pills) for softer highlighting.
