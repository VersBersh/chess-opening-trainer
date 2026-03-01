# Spaced Repetition (SM-2)

The app uses the SM-2 algorithm to schedule card reviews. SM-2 is implemented directly in Dart rather than using a library — the algorithm is ~40 lines of code and having full control avoids an external dependency.

Operates on the **ReviewCard** model defined in [models.md](models.md).

## Algorithm

### Input: Quality Rating (0-5)

Quality is derived automatically from the drill based on mistake count — no manual rating needed.

| Mistakes | Quality | Meaning |
|----------|---------|---------|
| 0 | 5 | Perfect recall |
| 1 | 4 | Recalled with hesitation |
| 2 | 2 | Barely recalled |
| 3+ | 1 | Failed to recall |

### Update Rules

**If quality < 3 (fail):**
- Reset `repetitions` to 0
- Reset `interval_days` to 1
- Ease factor is still adjusted (see below)

**If quality >= 3 (pass):**
- Increment `repetitions`
- Update `interval_days`:
  - repetitions = 1 → interval = 1
  - repetitions = 2 → interval = 6
  - repetitions > 2 → interval = previous interval * ease_factor

**Ease factor adjustment (always applied):**
```
EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
```
Where `q` is the quality rating. The ease factor has a floor of 1.3.

**Next review date:**
```
next_review_date = today + interval_days
```

### Pseudocode

```dart
ReviewCard updateCard(ReviewCard card, int quality) {
  // Adjust ease factor
  var ef = card.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (ef < 1.3) ef = 1.3;

  int interval;
  int repetitions;

  if (quality < 3) {
    // Failed — reset
    repetitions = 0;
    interval = 1;
  } else {
    // Passed — advance
    repetitions = card.repetitions + 1;
    if (repetitions == 1) {
      interval = 1;
    } else if (repetitions == 2) {
      interval = 6;
    } else {
      interval = (card.intervalDays * ef).round();
    }
  }

  return card.copyWith(
    easeFactor: ef,
    intervalDays: interval,
    repetitions: repetitions,
    nextReviewDate: today.add(Duration(days: interval)),
    lastQuality: quality,
  );
}
```

## Interactions with Features

- **Drill mode** calls the SM-2 update after each card is completed, mapping mistake count to quality.
- **Focus mode Phase 1** (due cards) updates SM-2 normally.
- **Focus mode Phase 2** (extra practice) does **not** update SM-2.
- **Line management** creates new ReviewCards with default values when a new leaf node is added to the repertoire.
