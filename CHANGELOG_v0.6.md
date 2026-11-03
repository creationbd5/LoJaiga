# v0.6 clean source package

- Corrected source tree for GitHub upload: exactly one LoJaiga folder.
- Added missing Config/Info.plist and explicit XcodeGen source folders.
- Added check in GitHub Actions before Xcode builds.
- Preserved two recorded voice phrase slots, location radius, OCR screenshot import and compact in-app preview.

**No live screen-broadcast/OCR extension was added.** This is a clean compilation baseline. Planned live capture requires an explicit, user-controlled ReplayKit broadcast extension, notification permissions and real-device validation. It must never be described as already working.
