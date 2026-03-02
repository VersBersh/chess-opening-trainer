# CT-36: Discovered Tasks

1. **CT-42: Visually verify and calibrate pill label offset after tap-target change**
   - Title: Verify pill label offset after 44dp tap-target wrapper
   - Description: The `_kLabelBottomOffset` was changed from -14 to -4 based on arithmetic estimation. Visually verify in the running app that labels appear correctly below pill decorations. Adjust the offset if mispositioned.
   - Why discovered: The implementation agent could not run the app to verify the label positioning empirically; the offset was calculated rather than measured.

2. **CT-43: Evaluate pill row height impact from 44dp tap target**
   - Title: Evaluate vertical space impact of 44dp pill tap targets
   - Description: Each pill row is now 48dp (44dp tap target + 4dp runSpacing), up from ~34dp. The visible decoration is more compact but the layout height increased. Evaluate whether the added vertical space is acceptable or if `_kPillMinTapTarget` or `runSpacing` should be adjusted.
   - Why discovered: The plan noted this as a known trade-off (compact visual vs taller layout) that requires product feedback.
