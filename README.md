# Lo Jaiga v0.6 — Clean GitHub Source Baseline

**Status: source package, NOT a built or device-verified IPA.**

This release fixes packaging problems from previous ZIPs:
- Restores `Config/Info.plist` required by `project.yml`.
- Explicitly references `LoJaigaApp.swift`, `Models`, `Services`, `Views`, and the asset catalog in `project.yml`.
- Keeps `Logo.imageset`, `BrandMascot.imageset`, and `AppIcon.appiconset` **inside** `LoJaiga/Assets.xcassets` (no duplicate standalone `Contents.json` copies).
- Adds a GitHub Actions source-tree check for required files.

## What this version actually does
- Import a saved Uber offer screenshot manually for Apple Vision OCR, with raw-text diagnostics.
- Evaluate Good/Bad offers against fare, km, hour, pickup and location preferences.
- Configure up to 5 preferred drop-offs and 5 avoid locations, each with radius and map picker.
- Two experimental, user-activated voice commands: `Lo Jaiga` and `Baad Dey`.
- Manually save and review trips. Save data locally.
- Display an in-app compact offer preview and mascot on Home.

## Not present / limitations
- **No continuous live Uber screen reading**. A ReplayKit Broadcast Upload Extension, its own processing pipeline, and real-world testing would be needed.
- **No iOS floating overlay above Uber**. Notification previews are in-app only.
- **No Uber Accept/Match auto-click**. iOS does not offer a supported generic cross-app tap API.
- **Not secure speaker biometrics**. Recorded samples provide a convenience comparison only.
- No verified CarPlay integration.

## Upload safely from Windows 10
GitHub web folder uploading previously produced `LoJaiga/LoJaiga/.gitattributes` with missing `Services` and `Views`. **Avoid uploading files one by one on the website.**

Recommended: make a NEW empty GitHub repository or clone existing repository in GitHub Desktop, then copy ALL contents of this folder into the repository root, including hidden `.github/`, with directories intact. Before committing, check for these exact paths:

```
.github/workflows/build-ios.yml
Config/Info.plist
LoJaiga/LoJaigaApp.swift
LoJaiga/Models/TripModels.swift
LoJaiga/Services/TripStore.swift
LoJaiga/Services/VoiceCommandEngine.swift
LoJaiga/Services/CommandRouter.swift
LoJaiga/Views/RootView.swift
LoJaiga/Assets.xcassets/BrandMascot.imageset/Contents.json
project.yml
```

Then commit and push to `main`. See `WINDOWS_UPLOAD_GUIDE.md`. In Actions, select the latest run. If green, download `LoJaiga-unsigned-ipa` artifact and sideload-sign it; green build does not prove OCR or speech runtime accuracy.
