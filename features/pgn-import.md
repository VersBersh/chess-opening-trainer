# PGN Import

PGN import converts a PGN file or pasted text into repertoire tree nodes. The parser handles the subset of PGN that maps to the repertoire's data model: move sequences and variations (RAV). Imported moves merge into the existing tree using the same deduplication logic as manual entry.

**Phase:** 3 (Repertoire Management)

## Domain Models

Uses **Repertoire**, **RepertoireMove**, and **ReviewCard** from [architecture/models.md](../architecture/models.md).

PGN import introduces no new persisted models. It produces the same `RepertoireMove` and `ReviewCard` records as manual line entry via [line-management.md](line-management.md).

## Input Methods

Two entry points feed the same parser pipeline:

### File Picker

- A system file picker filtered to `.pgn` files.
- The selected file is read as UTF-8 text and passed to the parser.
- Large files (multi-megabyte PGN databases) should be handled gracefully — the parser streams or chunks the input rather than loading the entire file into memory at once.

### Paste from Clipboard

- A text area where the user pastes PGN text directly.
- Useful for copying a game from a website or sharing between apps.
- The pasted text is passed to the same parser as the file picker.

Both methods produce the same intermediate representation before merge.

## PGN Parsing

### Supported Features

The parser handles the minimum viable subset of PGN:

- **Movetext:** Standard algebraic notation move sequences (e.g., `1. e4 e5 2. Nf3 Nc6`).
- **RAV (Recursive Annotation Variations):** Parenthetical variations at arbitrary nesting depth (e.g., `1. e4 (1. d4 d5) 1...c5`). These map directly to branches in the repertoire tree.
- **Game headers:** The `[White]`, `[Black]`, and `[Result]` tags are parsed for color inference (see below). Other headers are ignored.
- **Game termination markers:** `1-0`, `0-1`, `1/2-1/2`, `*` are recognized as end-of-game.

### Ignored Features

The following PGN features are parsed but discarded in v1:

- **Comments** (`{...}` and `;...`): Discarded. The `RepertoireMove.comment` field exists but is unused in the current UI. Storing comments is a future enhancement.
- **NAGs** (`$1`, `$2`, etc.): Discarded.
- **Clock data, eval annotations:** Discarded.

### Parser Implementation

The `dartchess` package provides PGN parsing primitives. The spec assumes the parser can:

1. Tokenize PGN movetext into individual moves.
2. Validate each move against the current board position (detecting illegal moves).
3. Handle RAV by maintaining a stack of positions — entering a parenthetical pushes the current position, exiting pops it.

If `dartchess` does not provide full PGN parsing with RAV support, a custom parser must be built on top of its move validation.

## Multi-Game Handling

A PGN file can contain multiple games separated by double newlines and header blocks.

### Behavior

All games in the file are imported and merged into a single repertoire tree. The user selects the target repertoire before import begins.

- Games that share opening moves merge naturally (the tree deduplicates shared prefixes).
- Each game produces one or more lines (one main line plus any RAV branches).
- If a game's color does not match the user's intent, the color inference rules below apply.

### No Game Selection UI (v1)

In v1, all games are imported without a selection step. This is the simplest approach. A game picker (letting the user select which games to import from a multi-game file) is deferred to a future version.

## Color Inference

Imported lines need a color context to determine which moves are the user's and which are the opponent's. Color is derived from the leaf move's depth in the tree (odd depth = white, even depth = black), not stored on any model. However, during import the system must know which side the user intends to play so it can orient the lines correctly in the tree.

### Rules

1. **Repertoire context is primary.** If the repertoire already contains lines, the existing tree structure provides implicit color context. Imported moves that follow existing branches inherit the tree's structure.
2. **PGN headers as hint.** If the PGN contains `[White "username"]` or `[Black "username"]` headers, and the user has configured their name in the app, the system can infer which side the user was playing.
3. **User prompt as fallback.** Before import begins, the user is asked: "Are you importing lines for White, Black, or both?" This explicit selection resolves any ambiguity.
4. **"Both" option.** When the user selects "both," each game's lines are imported as-is. The leaf depth determines the derived color naturally.

### Conflict Handling

If the PGN's implicit color (e.g., the user was Black in the game) conflicts with the selected import color (e.g., the user chose "White"), the system warns and skips the conflicting game rather than importing it with the wrong orientation.

## Merge Behavior

Imported moves merge into the existing repertoire tree using the same logic as manual entry in [line-management.md](line-management.md):

1. **Walk the tree from the root.** For each move in the imported line, check if a matching move (same SAN at the same parent) already exists in the tree.
2. **Follow existing branches.** If the move exists, follow it without creating a duplicate. The sibling uniqueness constraint (`idx_moves_unique_sibling`) enforces this at the database level.
3. **Create new nodes.** When the imported line diverges from the existing tree, create new `RepertoireMove` records for the remaining moves.
4. **Create cards for new leaves.** Only new leaf nodes generate new `ReviewCard` records with default SR values (ease factor 2.5, interval 1, repetitions 0).
5. **No card duplication.** If the imported line ends at an existing leaf, no new card is created.
6. **Extending existing lines.** If the imported line extends beyond an existing leaf, the same extension logic from line-management.md applies: the old card is removed and a new card is created for the new leaf with default SR values.

### Atomic Import

Each game's import is atomic — if parsing fails partway through a game (e.g., illegal move), that entire game is rolled back. Successfully parsed games are committed independently. This is a partial-import strategy: valid games are imported, invalid ones are reported.

## Error Handling

### Malformed PGN

- **Unparseable movetext:** If the parser cannot tokenize the movetext, the game is skipped and an error is reported (e.g., "Game 3: Could not parse movetext").
- **Illegal moves:** If a move is not legal in the current position, the game is skipped with a specific error (e.g., "Game 3, move 12: Nxe5 is not legal in this position").
- **Truncated files:** If the file ends mid-game (no termination marker), the partial game is skipped.

### Import Report

After import completes, the user sees a summary:

- Number of games processed.
- Number of lines imported (new leaves created).
- Number of games skipped due to errors, with per-game error descriptions.
- Number of moves that merged with existing tree nodes (informational, not an error).

The user can dismiss the report and inspect the imported lines in the repertoire browser.

### No Preview (v1)

In v1, there is no preview step before import commits. The user sees the import report after the fact. A preview screen (showing what lines would be created before committing) adds significant UI work and is deferred.

## Dependencies

- **Repository layer:** Uses `saveMove` for each imported move, with the same deduplication behavior as manual entry. Uses `saveReview` for new leaf cards.
- **Card creation:** Follows the same leaf-detection logic as line-management.md.
- **`dartchess` package:** Provides move validation and PGN parsing primitives. The spec must confirm at implementation time what the library handles vs. what must be custom-built.
- **Repertoire browser:** The user navigates to the repertoire browser to inspect imported lines after import.

## Key Decisions

> These are open questions that must be resolved before or during implementation.

1. **What PGN features to support beyond v1.** Comments could be stored in `RepertoireMove.comment` (the field exists but is unused). NAGs could map to a future annotation system. This is a meaningful scope lever for future phases.

2. **Preview before import.** Should the user see what lines will be created before committing? Important for large PGN files to prevent surprises. Adds significant UI work. Deferred in v1 but may be needed before v1 ships if user testing reveals import anxiety.

3. **Multi-game selection.** The current spec imports all games. A game picker would let users select which games to import from a large PGN database. The question is whether this is needed for the typical use case (importing a handful of games) or only for power users with large databases.

4. **Comment handling.** Discard vs. store in `RepertoireMove.comment`. Storing is low-effort at the parse level but raises UI questions: where do comments appear? Are they editable? This interacts with the repertoire browser spec.

5. **`dartchess` RAV support.** The parser implementation depends on what `dartchess` provides. If the library does not handle RAV natively, the custom parser effort is nontrivial. This must be spiked early.

6. **Import size limits.** Should there be a cap on file size or number of games? A PGN database with thousands of games could create tens of thousands of tree nodes. The import report and potential preview become essential at that scale.
