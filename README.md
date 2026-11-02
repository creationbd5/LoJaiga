# Lo Jaiga v0.4 • Simplified iPhone test project

A small native iPhone SwiftUI project for personal, user-driven Uber offer **screenshot** evaluation. This is not an Uber integration.

## Implemented / testable
- Eye-soft dark UI, brand mascot from v0.3.
- Screenshot import OCR, manual editing, sample offer, Good/Bad rules, trip logging and history.
- **Five** preferred drop-off and **five** avoided area/road slots (existing persisted model).
- New map picker: search with Apple Maps, choose a result or tap to pin location; configure radius per slot.
- Two configurable, separately recorded experimental voice phrases: `Lo Jaiga` reads current local offer verdict, `Baad Dey` logs local skip. Older 10-slot command settings are migrated to the first two slots.
- Google Maps, Apple Maps, Waze routing links.

## Not implemented / not possible in standard iOS app
- Automatic reading of Uber's screen while Uber is foregrounded; user must share a screenshot.
- Automatic Uber Accept / Match / Decline tapping. Voice commands only affect Lo Jaiga.
- Secure biometric owner-only identification: the experimental spectral filter is not secure, can be fooled by recordings, and may fail in car noise.
- Guaranteed Uber policy compliance; CarPlay or floating Uber overlay.

## Build on Windows 10
1. Push the **contents** of this folder to your GitHub repository `main`, preserving `.github/workflows` and `LoJaiga/Assets.xcassets`.
2. Open GitHub Actions → Build Lo Jaiga unsigned IPA. Inspect failures under build log; **we could not run Xcode in this environment**.
3. Download `LoJaiga-unsigned-ipa` artifact after green success; extract ZIP.
4. Sideloadly can attempt to sign the IPA using your own free Apple account, with 7-day signing limits. Keep a backup of existing local data before removing an old app.
5. Test map selection, sample offer, screenshot OCR, voice controls while parked.

Notes: do not use while driving; do not give an unverified OCR-based recommendation for critical decisions. Avoid-area filters do not have live Uber route geometry.
