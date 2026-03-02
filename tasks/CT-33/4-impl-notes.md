# CT-33: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_tree_widget.dart` | Enlarged chevron and label icon tap targets from ~26-28dp to 48dp using `kMinInteractiveDimension`-sized `SizedBox` + `Center` wrappers; updated placeholder `SizedBox` width to match; removed explicit vertical padding (top/bottom 4.0) from row `Padding`. |
| `src/test/widgets/move_tree_widget_test.dart` | Added two new widget tests verifying that taps within the enlarged 48dp area but outside the visual icon bounds correctly trigger `onEditLabel` / `onNodeToggleExpand` rather than `onNodeSelected`. |

## Deviations from Plan

None. All four steps were implemented exactly as specified.

## Follow-up Work

- **Viewport height in tests**: The existing test harness uses `SizedBox(height: 600)`. With the taller rows (48dp min vs. previous ~28dp), fewer rows fit on screen. If future tests reference many rows simultaneously, the viewport height may need increasing. No existing tests broke from this change since they use at most 2-3 visible rows.
- **Horizontal space on narrow screens**: As noted in the plan risks, the 48dp chevron + 48dp label icon consume 96dp of horizontal space. On 360dp screens with deep indentation, text space may become tight. Consider a separate ticket to cap indentation depth if this becomes a usability issue.
