# Testing Strategy

Thorough but meaningful tests. Every test should justify its existence by testing real behavior or catching a likely regression. No tests for boilerplate, trivial getters, or framework plumbing.

## Principles

1. **Test behavior, not implementation.** Tests verify what the system does, not how it does it. A refactor that preserves behavior should not break tests.
2. **The repository interface is the primary seam.** Business logic (drill engine, SM-2, line management) is tested against mock repositories. Repository implementations are tested against a real SQLite database.
3. **Favor unit tests.** They're fast, stable, and precise. Use widget tests only where interaction matters. Use integration tests sparingly for critical end-to-end flows.
4. **Tests should read like specs.** A test name and body should make the expected behavior obvious. If someone reads only the tests, they should understand what the feature does.

## Test Pyramid

```
        ╱  Integration  ╲        ← Few: critical user journeys
       ╱   Widget Tests   ╲      ← Moderate: interaction-heavy screens
      ╱     Unit Tests      ╲    ← Many: business logic, algorithms, data
     ╱________________________╲
```

## Layers and What to Test

### Unit Tests (services/, models/)

These are the bulk of the test suite. Pure Dart, no Flutter dependencies, fast.

**SM-2 Scheduler**
- Quality 5 (0 mistakes): interval increases, ease factor rises
- Quality 3 (1 mistake): interval still increases but ease drops
- Quality 2 (2 mistakes): interval resets to 1, ease drops
- Quality 1 (3+ mistakes): interval resets to 1, ease drops further
- Ease factor never goes below 1.3
- First review: interval = 1 regardless of quality
- Second review: interval = 6 on pass
- Subsequent reviews: interval = previous * ease_factor
- Edge case: very high ease factor after many perfect reviews
- Edge case: card that has been failing repeatedly (ease at floor)

**SM-2 Reference Validation (table-driven)**

Table-driven tests that run a sequence of reviews through the SM-2 scheduler and compare the full output state against reference values computed from the original algorithm. Each test case is a sequence of (quality) inputs applied to a fresh card (ease 2.5, interval 1, repetitions 0). After each review, the test asserts on ease_factor, interval_days, and repetitions.

These reference values must be verified against the original SM-2 algorithm before being committed to the test suite.

Test sequences:

- **Sequence A — Perfect recall (all quality 5):** 10 consecutive reviews. Validates steady ease growth and multiplicative interval increases after rep 2.
- **Sequence B — Mixed performance:** [5, 4, 5, 2, 5, 5, 5, 4, 5, 5]. Validates pass/fail boundary transitions (quality 2 resets interval and repetitions).
- **Sequence C — Repeated failure then recovery:** [1, 1, 1, 5, 5, 5, 5, 5]. Validates ease floor (1.3) and recovery with quality 5 from a low ease factor.
- **Sequence D — Boundary quality (quality 3):** [5, 5, 3, 3, 5, 5]. Validates that quality 3 passes (interval increases) but ease drops.
- **Sequence E — Single mistake patterns:** [4, 5, 4, 5, 4, 5]. Validates quality 4 leaves ease unchanged and quality 5 increases it.

Use `closeTo(expected, 0.01)` for ease factor assertions. Interval assertions should be exact integers.

**Drill Engine**
- Intro move calculation: stops at first branch point for user's color
- Intro move calculation: stops at cap (3 user moves) even without branch
- Intro move calculation: black lines — opponent moves first
- Intro move calculation: very short line (fewer moves than cap)
- Correct move: advances to next position, triggers opponent response
- Wrong move (not in repertoire): incremented mistake count, flagged as mistake
- Wrong move (sibling line correction): no mistake increment, flagged as correction
- Card completion: mistake count maps to correct SM-2 quality
- Card completion with 0, 1, 2, 3+ mistakes
- Extra practice mode: SM-2 not updated
- Line with single branch — no intro ambiguity
- Line that is entirely auto-played (very short)

**Line Management Logic**
- Adding a new line creates a leaf and a card
- Adding a duplicate line (same path) does not create a new card
- Adding a line that branches from an existing one creates a new card without affecting the original
- Extending an existing line: old card deleted, new card created with default SR
- Extending a line: new card has default SR state (ease 2.5, interval 0, repetitions 0), not inherited from old card
- Labeling: aggregate display name computed by concatenating labels along root-to-leaf path
- Labeling: renaming a label updates all descendant aggregate display names
- ~~Label impact warning: adding a label between existing labels warns about affected display names~~ *(deferred to post-v0)*
- ~~Label impact warning: warning is advisory — user can proceed~~ *(deferred to post-v0)*
- ~~Transposition label conflict: labeling a node warns if other nodes with the same FEN have different labels~~ *(deferred to post-v0)*
- ~~Transposition label conflict: warning is advisory — user can proceed despite conflict~~ *(deferred to post-v0)*
- Deleting a leaf removes its card
- Deleting a leaf does not cascade to parent
- Deleting a leaf does not auto-create a card for the now-childless parent
- Subtree deletion: deleting a branch removes all descendant moves and their cards
- Subtree deletion: confirmation reports the correct affected line and card count

**Orphan Handling at Deletion Site**
- Deleting a leaf where parent has other children: parent is unaffected
- Deleting a leaf where parent has no other children: parent is flagged as childless
- "Keep shorter line" choice: card is created for the now-childless parent
- "Remove move" choice: childless parent is deleted and its own parent is checked (recursive)
- "Remove move" applied recursively up the tree stops at a node that still has children

**Line Parity Validation**
- Line depth parity matches board orientation (odd depth = white, even depth = black)
- Parity mismatch produces a warning
- User can flip board and reconfirm after parity mismatch
- Derived color from leaf depth: odd = white, even = black

**Move Buffering**
- Moves are buffered in memory during entry, not persisted until confirm
- Abandoning entry leaves no orphaned moves in the database
- Confirming entry persists all buffered moves and creates a card

**Browse/Edit Mode**
- Browse mode prevents move entry on the board
- Edit mode allows appending moves to leaf positions
- Mode toggle switches between browse and edit correctly

**Repertoire Tree Operations**
- Build tree from flat move list
- Walk root-to-leaf path
- Find all leaves in a subtree
- Find branch points
- Determine children of a node
- Derived color: color is correctly derived from leaf depth (odd = white, even = black)

### Repository Tests (repositories/local/)

These run against a real in-memory SQLite database (Drift supports this for testing). They verify that the SQL queries, indexes, and constraints work correctly.

**RepertoireRepository**
- CRUD for repertoires
- CRUD for moves
- Get root moves (parent_move_id is null)
- Get child moves for a parent
- Get full line (root to leaf path) for a leaf move
- Deleting a move cascades to child moves (ON DELETE CASCADE)
- Deleting a repertoire cascades to moves and cards (ON DELETE CASCADE)
- Cascade deletion: deleting a repertoire leaves no orphaned moves or cards
- Cascade deletion: deleting a move cascades to all descendant moves
- Subtree deletion: deleting a branch removes all descendants and their associated cards
- Duplicate move prevention (same parent + same SAN)
- Deletion-site orphan check: after deleting a leaf, `isLeafMove(parentId)` correctly identifies a newly childless parent
- Deletion-site orphan check: parent with remaining children is not flagged

**ReviewRepository**
- Get due cards filters by next_review_date correctly
- Get due cards for a specific repertoire
- Get cards for a subtree (focus mode query)
- Save review updates all SR fields
- Delete card by ID
- Unique constraint on leaf_move_id (no duplicate cards per leaf)
- Card with no last_quality (freshly created)
- Extending a line: new card is created with default SR state (ease 2.5, interval 0, repetitions 0)
- Extending a line: old card is deleted, new card does not inherit old SR values

**Data integrity**
- Foreign key enforcement (PRAGMA foreign_keys = ON)
- Cannot create a card for a non-existent leaf_move_id
- Cannot create a move for a non-existent repertoire_id
- ON DELETE CASCADE: deleting a repertoire removes all associated moves and cards
- ON DELETE CASCADE: deleting a move removes all child moves

### Widget Tests (screens/, widgets/)

These test Flutter widgets in isolation with mocked dependencies. Focus on interaction behavior, not pixel-perfect layout.

**Drill Screen**
- Displays the board in the correct orientation based on card color
- Auto-plays intro moves with animation
- Accepts user move via board interaction
- Shows X icon and arrow on mistake
- Shows arrow only (no X) on sibling line correction
- Reverts incorrect move after pause
- Advances to next card after line completion
- Shows progress indicator (e.g., "Card 3 of 12")
- Handles empty card queue (no due cards)

**Line Entry Screen**
- Board starts at initial position
- Plays both sides' moves sequentially
- Flip board toggle changes orientation
- Confirm creates card with selected color
- Branch from existing line navigates to branch point first
- Label input shows aggregate display name preview
- ~~Label impact warning is displayed when adding a label affects descendant display names~~ *(deferred to post-v0)*
- ~~Transposition label conflict warning is displayed when another node with the same FEN has a different label~~ *(deferred to post-v0)*
- ~~Label warnings are advisory — user can dismiss and proceed~~ *(deferred to post-v0)*
- Take-back removes the last buffered move and reverts the board
- Take-back works repeatedly to undo multiple moves
- Take-back is disabled at the starting position
- Take-back is disabled at a branch point (cannot undo beyond branch root)
- Line parity validation: warning shown when line depth parity does not match board orientation
- Line parity validation: user can flip board and reconfirm after mismatch
- Board orientation in drill matches derived color from leaf depth (odd = white, even = black)
- Move buffering: moves are held in memory during entry, not persisted until confirm
- Move buffering: abandoning entry leaves no orphaned moves

**Browse/Edit Mode**
- Browse mode prevents move entry on the board
- Edit mode allows appending moves to leaf positions
- Mode toggle switches between browse and edit
- Browse mode still allows navigation (tap to view position)

**Repertoire Browser**
- Displays tree structure with expand/collapse
- Labeled nodes are visually distinguished
- Tap navigates to position on board
- Entry point to drill mode and focus mode
- Subtree deletion: confirmation dialog shows affected line and card count
- Subtree deletion: confirming removes all descendants from the tree view

### Integration Tests

Minimal set of end-to-end tests that verify critical user journeys through the real app (real database, real widgets). These are slow and should only cover flows where the unit + widget tests leave gaps.

**Journey 1: First line to first drill**
1. Create a repertoire
2. Enter a line (play moves on board)
3. Confirm the line
4. Enter drill mode
5. Play through the card correctly
6. Verify SR state is updated

**Journey 2: Mistake during drill**
1. Set up a repertoire with a known line
2. Enter drill mode
3. Play an incorrect move
4. Verify mistake feedback (X + arrow)
5. Play the correct move
6. Complete the line
7. Verify SR quality reflects the mistake

**Journey 3: Focus mode transition**
1. Set up a repertoire with labeled variation and multiple lines
2. Enter focus mode for the labeled variation
3. Complete all due cards
4. Transition to extra practice
5. Verify SR is not updated for extra practice cards

## Test Data

### Fixtures

Define reusable test repertoires as fixtures rather than rebuilding them in each test:

- **Simple line**: 1. e4 e5 2. Nf3 Nc6 3. Bb5 (3 moves, no branches)
- **Branching tree**: 1. e4 with two responses (1...e5 and 1...c5), each going 2-3 moves deep
- **Deep Najdorf**: a 15+ move line for testing intro move cap and deep path reconstruction
- **Labeled tree**: tree with labels "Sicilian", "Najdorf", "Dragon" at appropriate nodes (aggregate names: "Sicilian — Najdorf", "Sicilian — Dragon")

### Mock Repositories

For unit and widget tests, provide mock implementations of `RepertoireRepository` and `ReviewRepository` that return pre-defined data. Use `mockito` or hand-written fakes — whichever is simpler for the test.

## What NOT to Test

- Widget layout / styling (colors, padding, font sizes) — too brittle, low value
- dartchess or flutter_chessground internals — tested by their own packages
- Drift query generation — Drift is well-tested; test the queries' results, not the SQL
- Trivial model constructors or copyWith methods
- Boilerplate (main.dart, route definitions, theme config)

## Test File Structure

```
test/
  services/
    sm2_scheduler_test.dart
    drill_engine_test.dart
    line_management_test.dart
    pgn_importer_test.dart
  repositories/
    local_repertoire_repository_test.dart
    local_review_repository_test.dart
  screens/
    drill_screen_test.dart
    line_entry_screen_test.dart
    repertoire_browser_screen_test.dart
  fixtures/
    test_repertoires.dart         # reusable test data builders
    mock_repositories.dart        # mock/fake repository implementations
  integration/
    first_line_drill_test.dart
    mistake_drill_test.dart
    focus_mode_test.dart
```

## Running Tests

- `flutter test` — runs all unit and widget tests
- `flutter test test/services/` — run a specific layer
- `flutter test --coverage` — generate coverage report
- Integration tests: `flutter test integration_test/` (requires a running app instance)

## Coverage Expectations

No hard coverage target — coverage percentage is a poor proxy for test quality. Instead:

- Every public method on a service class should have at least one test
- Every repository query should have a test verifying its filtering/sorting
- Every user-facing error state (mistake, correction, empty queue) should have a widget test
- Edge cases called out in feature specs should have corresponding tests
