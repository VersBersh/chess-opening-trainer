# CT-11.5: Discovered Tasks

## CT-11.8: Dynamic label positioning for accessibility text scaling

**Title:** Dynamic label positioning under accessibility text scaling
**Description:** The `_kLabelBottomOffset = -14` constant is calibrated for default text scale. Under accessibility text scaling, both the pill body and label text grow, so the label may not be positioned correctly beneath the pill. Replace the fixed offset with a `LayoutBuilder` or `CustomSingleChildLayout` that computes label placement from the actual pill height.
**Why discovered:** During implementation, the plan's risk section identified that the fixed pixel offset is fragile under non-default text scaling. The design review also flagged this as a semantic coupling between the offset constant and the label font size.

## CT-11.9: Handle very long pill label strings

**Title:** Handle very long pill label text gracefully
**Description:** Labels use `TextOverflow.visible` and are unconstrained in width, so very long labels could extend far beyond the pill horizontally. While the spec allows overflow under neighbors, extremely long labels could overlap many pills or extend off-screen. Consider adding a max-width constraint or `TextOverflow.ellipsis` after a reasonable width.
**Why discovered:** During implementation, the plan's risk section noted that unconstrained label width is acceptable for typical short chess opening names but could be problematic if longer labels are introduced in the future.
