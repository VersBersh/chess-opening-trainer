---
id: CT-53
title: Fix pill height and equalize gaps in Add Line screen
depends: []
specs:
  - design/ui-guidelines.md
  - features/add-line.md
files: []
---
# CT-53: Fix pill height and equalize gaps in Add Line screen

**Epic:** none
**Depends on:** none

## Description

In the Add Line screen, the move pills are slightly too tall and the vertical spacing between rows is inconsistent. Specifically:

1. **Pills are too tall** — the vertical size of each pill could be reduced for a more compact appearance.
2. **Inconsistent gaps** — the gap between the bottom of the board and the first row of pills is smaller than the gap between the two rows of pills. These gaps should be equal.

### Spec updates required

**`design/ui-guidelines.md`** — Add a rule under Pills & Chips: "The vertical gap between the board and the first pill row must equal the gap between subsequent pill rows. Pill rows should use consistent, uniform vertical spacing throughout."

**`features/add-line.md`** — In the Move Pills > Display section, add a note that pill height should be compact (not oversized) and that the gap between the board bottom and the first pill row must match the inter-row gap.

## Acceptance Criteria

- [ ] Update `design/ui-guidelines.md` Pills & Chips section with uniform gap rule
- [ ] Update `features/add-line.md` Move Pills Display section with compact height and gap consistency requirements
- [ ] Gap between board bottom and first pill row equals gap between pill rows
- [ ] Pill height is reduced to a more compact size
- [ ] Layout looks balanced with 1 row of pills and with 2+ rows of pills

## Notes

- This may be a simple padding/margin adjustment in the pill widget and/or the spacing between the board and the pill area.
- Check whether the same issue exists in any other screen that displays pills (e.g., Repertoire Manager).
