# Lo Jaiga v0.7 Experimental Live OCR Test

## What is implemented
- A ReplayKit Broadcast Upload Extension that samples at most one frame per second, runs local Vision OCR, uses an intentionally conservative provisional offer/price matcher, and tries to post a **TEST** local notification.
- A Live OCR tab containing the system broadcast picker and a notification permission request button.
- Image data and full OCR output are not written to disk, app group, Photos, or cloud. An in-memory fingerprint and last fare are used for duplicate control.

## Not implemented / not verified
- Accurate pickup/ride distance and duration extraction, preferred destination / avoid area filtering in the broadcast extension, and Good/Bad verdict. Existing manual screenshot analysis remains separate.
- Reliable delivery of notifications from a broadcast extension while Uber is foregrounded (iOS background / authorization behavior must be tested).
- Uber offer sound trigger, voice-triggered Uber Accept/Match, persistent background voice monitoring, CarPlay.
- The project has not been compiled with Xcode in this environment. Unsigned IPA sideloading may fail to install or load the broadcast extension; proper signing may be required.

## Install & test
1. Extract this ZIP and replace the repository root with the ZIP's contents (remove outdated duplicate Swift source/asset directories from previous attempts). Do not upload the ZIP itself as a GitHub source file.
2. Push to GitHub. GitHub Actions generates Xcode project with XcodeGen, runs simulator tests, builds unsigned device app and verifies `.appex` is embedded.
3. Sideloadly signing might fail for an app containing an extension. If so, report the exact signing message. A properly provisioned Apple Development team may be necessary.
4. In Lo Jaiga open **Live OCR**, tap **Allow Offer Notifications**, then the broadcast icon. The iOS broadcast selector should list Lo Jaiga Broadcast.
5. If the selector does not list it, do not assume OCR works. Capture a screenshot of the selector and GitHub build log.
6. Test only while parked. A real Uber offer may be missed or misread; manually verify every trip.
7. A notification that says **Offer detected (TEST)** means only a candidate fare was found. It does not indicate profit.

## Technical limitations
`RPSystemBroadcastPickerView` requires a user action and the extension needs an iOS-compatible provisioning/signing arrangement. This experiment deliberately avoids App Groups entitlement (and hence avoids passing raw OCR to the app). Notifications are attempted from the upload extension; iOS may prevent or delay them. No extension-to-app OCR link yet. This is NOT production-ready.

## v0.7.1 stricter Uber-focused OCR filter
- Requires UberX, UberXL, Uber Comfort, Uber Green, or Trip Radar context, plus a fare, distance and minute values. Generic words such as Accept, Pickup, Matching do not qualify alone.
- Requires the same offer type and amount in two successive analyzed frames; throttled to 1 frame/s.
- No disk persistence of screenshots or OCR text. Only an ephemeral in-memory offer fingerprint is used for deduplication.
- **Not an app identity lock:** iOS does not tell this broadcast extension reliably which app is foregrounded. Non-Uber screenshots containing similar text can still match. Uber offer formats missing these markers may be missed.
- No sound trigger, Good/Bad notification, or verified delivery on a physical iPhone. This is a test build only.
