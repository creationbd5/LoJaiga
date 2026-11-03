# Lo Jaiga v0.5 UI / source update

Based on the v0.4 Simple iOS source.

## Added
- Compact, logo-free, highly legible offer preview **inside** Analyze Offer view, including GOOD/BAD status, fare, CAD/km, CAD/hr, pickup ETA, distance and destination.
- Keeps the existing mascot branding, 5 preferred and 5 avoided locations with radii and map selection, 2 voice commands, manual OCR import, and trip history.

## Not included / not claimed
- No cross-app Uber floating overlay: iOS does not expose arbitrary overlay windows on Uber.
- No automatic reading of Uber notifications or offer sounds.
- No live ReplayKit capture pipeline. Screenshot OCR remains manual.
- No Uber Accept/Match button automation.
- No guaranteed speaker authentication or CarPlay entitlement.

## Build
Use existing .github/workflows/build-ios.yml workflow. Build from the branch into which you commit the updated files, then download the unsigned IPA artifact; signing for device installation is a separate step. This source has not been compiled by Xcode in this environment.
