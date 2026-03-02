**Verdict** — `Needs Revision`

**Issues**
1. **Major (Step 6)**: The planned integration tests are not specific enough to prove the inline row icon is wired. If tests tap generic `Label` affordances, they can accidentally hit the existing action-bar Label button and pass even if row icons are broken.  
   **Fix**: Require finders scoped to tree-row inline controls (for example, row-scoped `IconButton`/tooltip finder), and assert behavior when no node is selected to confirm the inline path is independent of selection.

2. **Major (Step 5)**: Step 2 allows `Icons.label_outline` *or* `Icons.label`, but Step 5 test #1 hardcodes `Icons.label_outline` for each row. That is internally inconsistent and can fail valid implementations.  
   **Fix**: Either lock the implementation to one icon in Step 2, or change tests to assert presence of the label-action button per row without over-constraining the exact icon glyph.

3. **Minor (Step 5 completeness)**: The plan adds an optional `onEditLabel` API but does not include a widget test for the `null` callback case (icon hidden/disabled behavior).  
   **Fix**: Add a test verifying no actionable inline label control appears (or it is disabled) when `onEditLabel` is not provided, matching the intended optional callback contract.