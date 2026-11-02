# Lo Jaiga — iOS (SwiftUI, iOS 17+) · v0.2 test build

**Status: source only. It has NOT been compiled yet** (no Swift/Xcode toolchain was available when this was written; code was desk-checked and brace-balanced only). The first GitHub Actions run is the first real compile — expect a few small fixes. See `BUILD_WINDOWS_TO_IPHONE.md`.

## What the app does
| Area | State |
|---|---|
| Good / Bad offer analysis (score 0–100, reasons, est. net, net/hr) | Implemented, unit-tested logic |
| Offer entry by hand | Implemented |
| Offer entry from a screenshot you pick (Vision OCR) | Beta, Uber layout NOT verified |
| Shortcuts action "Check Offer Screenshot" (Action Button / Back Tap / Siri) | Implemented, you trigger it |
| Owner voice enrollment (10 commands) | Experimental |
| Voice commands (10) acting inside Lo Jaiga | Experimental, foreground-first |
| Trip history, filters, status, CSV export | Implemented |
| Destinations: home, 5 preferred, 5 avoid, real map lookup + radius | Implemented (needs internet for lookup) |
| Navigation hand-off to Google Maps / Apple Maps / Waze | Implemented |
| Performance: debounced file storage, no per-keystroke rewrites | Implemented |

## Apple / Uber restrictions (not bugs)
- **Auto Accept / Match in Uber: not possible and not built.** iOS apps cannot tap another app's buttons, and Uber has no public driver-offer API. Third-party "auto accept" tools for Uber/Lyft have drawn warnings from the companies, so don't try to bolt one on.
- **Uber live data** (offers, Trip Radar, busy areas, surge): only inside Uber's app. Not available.
- **CarPlay:** needs an Apple-granted entitlement for an approved category (audio, communication, EV charging, navigation, parking, quick food ordering, etc.). Not enabled; a sideloaded build can't use it.
- **Always-on "Lo Jaiga" wake word:** not offered to third-party apps. Listening is on/off by you; iOS may stop it in the background.
- **Owner-voice security:** iOS has no public speaker-verification API. The filter here is a crude spectral comparison — not secure, no replay defence, untested.
- Free Apple ID sideloading: app expires every 7 days; re-sign it.

## Code map
`Models/TripModels.swift` data + tolerant decoding · `Services/OfferEvaluator.swift` scoring (pure) · `Services/VoiceCommandEngine.swift` listening + enrollment · `Services/CommandRouter.swift` voice → action · `Services/OfferOCR.swift` screenshot parser · `Services/OfferIntents.swift` Shortcuts action · `Services/GeoService.swift`, `MapLauncher.swift`, `Persistence.swift`, `TripStore.swift` · `Views/*` · `LoJaigaTests/*`.

## Branding
Mascot/tagline appear only inside the app (Home). Palette: midnight charcoal, deep teal, muted mint, warm gold. Home no longer shows "Uber Driver Connected" because nothing is connected.
