# CT-1.1 Discovered Tasks

## ~~1. Take-back Support for ChessboardController~~ → COVERED by CT-2.6

- **Suggested task ID:** ~~Part of CT-2.x~~ → **CT-2.6** (now a formal task)
- **Title:** Add undo/take-back support to ChessboardController
- **Description:** The controller does not support undo/take-back. Line entry mode needs this for exploring variations. Options: maintain a move history stack in the controller, or let the parent manage position history externally via `setPosition()`.
- **Why discovered:** During implementation, the controller was designed with `setPosition()` and `playMove()` but no `undo()`. The line management feature spec references take-back support, which will require either extending the controller or managing state externally.
- **Status:** Superseded — now tracked as CT-2.6.
