# CT-9.4 Discovered Tasks

1. **Suggested ID:** CT-9.6
   **Title:** Extract shared banner gap constant
   **Description:** After CT-9.1 and CT-9.4 both add `EdgeInsets.only(top: 8)` independently, extract the value to a shared constant (e.g., `kBannerGap`) in a design-system/theme constants file, and update both screens to use it.
   **Why discovered:** Both CT-9.1 and CT-9.4 address the same banner-gap guideline on different screens. The plan's risk section noted this duplication would need resolution once both tasks land.
