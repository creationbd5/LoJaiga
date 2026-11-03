# Lo Jaiga v0.3 patched source (iPhone test build)

Based on the uploaded `LoJaiga-iOS-v0.2.zip`, not a live checkout of the GitHub repository.

## Changes
- Home screen redesigned with a reserved 230pt mascot image block, readable earnings, structured two-column quick actions, clear Manual Test Mode status.
- Duplicated `Logo.imageset` as `BrandMascot.imageset` and uses `Image("BrandMascot")` to make the branded image reference explicit. Check asset compilation on iPhone.
- Offer Analyzer: OCR diagnostic disclosure with raw recognized text and parsed values, copyable text, and a reproducible sample offer button.
- Saves taken/skipped status immediately and confirms whether logging succeeded.
- OCR parser supports km-before-minutes examples (e.g., `3.2 km • 8 min`) in addition to original patterns.
- Explicit Voice enrollment experimental labels and iOS 18 deployment for the AppIntents availability error.

## What does NOT work
No automatic Uber screen capture, no automatic Uber offer Match/Accept, no live surge data, no CarPlay entitlement, and **no secure owner-only biometric voice verification**. Do not use while driving.

## Upload to GitHub (Windows 10)
1. Extract ZIP. The directory contains `.github` (enable Windows **View > Hidden items**).
2. Prefer uploading the changed files with their same relative paths to `creationbd5/LoJaiga` on `main` (preserve other GitHub edits). For a clean full replacement, back up the repository first, then use GitHub Desktop to commit changes from this project.
3. `Actions` > latest `Build Lo Jaiga (unsigned IPA)` > Summary > Artifacts.
4. Use Sideloadly to sign/install unsigned IPA with your own Apple account. Free signing may require renewal after 7 days.

## Testing
1. On Home, check mascot appears and not blank.
2. Analyze > Load sample offer > see non-zero fare > Log: I took it.
3. History should now show a stored entry and home should show one logged trip.
4. Analyze > From screenshot (beta) > expand OCR diagnostic report; compare raw recognized text with parser values.
5. Verify 10 voice recordings are *not* treated as proof only your voice can trigger commands.

This code has **not** been compiled with Xcode in this environment. The GitHub Actions run is the first build verification step.
